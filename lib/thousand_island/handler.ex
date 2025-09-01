defmodule ThousandIsland.Handler do
  @moduledoc """
  `ThousandIsland.Handler` defines the behaviour required of the application layer of a Thousand Island server. When starting a
  Thousand Island server, you must pass the name of a module implementing this behaviour as the `handler_module` parameter.
  Thousand Island will then use the specified module to handle each connection that is made to the server.

  The lifecycle of a Handler instance is as follows:

  1. After a client connection to a Thousand Island server is made, Thousand Island will complete the initial setup of the
  connection (performing a TLS handshake, for example), and then call `c:handle_connection/2`.

  2. A handler implementation may choose to process a client connection within the `c:handle_connection/2` callback by
  calling functions against the passed `ThousandIsland.Socket`. In many cases, this may be all that may be required of
  an implementation & the value `{:close, state}` can be returned which will cause Thousand Island to close the connection
  to the client.

  3. In cases where the server wishes to keep the connection open and wait for subsequent requests from the client on the
  same socket, it may elect to return `{:continue, state}`. This will cause Thousand Island to wait for client data
  asynchronously; `c:handle_data/3` will be invoked when the client sends more data.

  4. In the meantime, the process which is hosting connection is idle & able to receive messages sent from elsewhere in your
  application as needed. The implementation included in the `use ThousandIsland.Handler` macro uses a `GenServer` structure,
  so you may implement such behaviour via standard `GenServer` patterns. Note that in these cases that state is provided (and
  must be returned) in a `{socket, state}` format, where the second tuple is the same state value that is passed to the various `handle_*` callbacks
  defined on this behaviour. It also critical to maintain the socket's `read_timeout` value by
  ensuring the relevant timeout value is returned as your callback's final argument. Both of these
  concerns are illustrated in the following example:

      ```elixir
      defmodule ExampleHandler do
        use ThousandIsland.Handler

        # ...handle_data and other Handler callbacks

        @impl GenServer
        def handle_call(msg, from, {socket, state}) do
          # Do whatever you'd like with msg & from
          {:reply, :ok, {socket, state}, socket.read_timeout}
        end

        @impl GenServer
        def handle_cast(msg, {socket, state}) do
          # Do whatever you'd like with msg
          {:noreply, {socket, state}, socket.read_timeout}
        end

        @impl GenServer
        def handle_info(msg, {socket, state}) do
          # Do whatever you'd like with msg
          {:noreply, {socket, state}, socket.read_timeout}
        end
      end
      ```

  It is fully supported to intermix synchronous `ThousandIsland.Socket.recv` calls with async return values from `c:handle_connection/2`
  and `c:handle_data/3` callbacks.

  # Example

  A simple example of a Hello World server is as follows:

  ```elixir
  defmodule HelloWorld do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      ThousandIsland.Socket.send(socket, "Hello, World")
      {:close, state}
    end
  end
  ```

  Another example of a server that echoes back all data sent to it is as follows:

  ```elixir
  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end
  ```

  Note that in this example there is no `c:handle_connection/2` callback defined. The default implementation of this
  callback will simply return `{:continue, state}`, which is appropriate for cases where the client is the first
  party to communicate.

  Another example of a server which can send and receive messages asynchronously is as follows:

  ```elixir
  defmodule Messenger do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(msg, _socket, state) do
      IO.puts(msg)
      {:continue, state}
    end

    def handle_info({:send, msg}, {socket, state}) do
      ThousandIsland.Socket.send(socket, msg)
      {:noreply, {socket, state}, socket.read_timeout}
    end
  end
  ```

  Note that in this example we make use of the fact that the handler process is really just a GenServer to send it messages
  which are able to make use of the underlying socket. This allows for bidirectional sending and receiving of messages in
  an asynchronous manner.

  You can pass options to the default handler underlying `GenServer` by passing a `genserver_options` key to `ThousandIsland.start_link/1`
  containing `t:GenServer.options/0` to be passed to the last argument of `GenServer.start_link/3`.

  Please note that you should not pass the `name` `t:GenServer.option/0`. If you need to register handler processes for
  later lookup and use, you should perform process registration in `handle_connection/2`, ensuring the handler process is
  registered only after the underlying connection is established and you have access to the connection socket and metadata
  via `ThousandIsland.Socket.peername/1`.

  For example, using a custom process registry via `Registry`:

  ```elixir

  defmodule Messenger do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      {:ok, {ip, port}} = ThousandIsland.Socket.peername(socket)
      {:ok, _pid} = Registry.register(MessengerRegistry, {state[:my_key], address}, nil)
      {:continue, state}
    end

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end
  ```

  This example assumes you have started a `Registry` and registered it under the name `MessengerRegistry`.

  # When Handler Isn't Enough

  The `use ThousandIsland.Handler` implementation should be flexible enough to power just about any handler, however if
  this should not be the case for you, there is an escape hatch available. If you require more flexibility than the
  `ThousandIsland.Handler` behaviour provides, you are free to specify any module which implements `start_link/1` as the
  `handler_module` parameter. The process of getting from this new process to a ready-to-use socket is somewhat
  delicate, however. The steps required are as follows:

  1. Thousand Island calls `start_link/1` on the configured `handler_module`, passing in a tuple
  consisting of the configured handler and genserver opts. This function is expected to return a
  conventional `GenServer.on_start()` style tuple. Note that this newly created process is not
  passed the connection socket immediately.
  2. The raw `t:ThousandIsland.Transport.socket()` socket will be passed to the new process via a
  message of the form `{:thousand_island_ready, raw_socket, server_config, acceptor_span,
  start_time}`.
  3. Your implementation must turn this into a `to:ThousandIsland.Socket.t()` socket by using the
  `ThousandIsland.Socket.new/3` call.
  4. Your implementation must then call `ThousandIsland.Socket.handshake/1` with the socket as the
  sole argument in order to finalize the setup of the socket.
  5. The socket is now ready to use.

  In addition to this process, there are several other considerations to be aware of:

  * The underlying socket is closed automatically when the handler process ends.

  * Handler processes should have a restart strategy of `:temporary` to ensure that Thousand Island does not attempt to
  restart crashed handlers.

  * Handler processes should trap exit if possible so that existing connections can be given a chance to cleanly shut
  down when shutting down a Thousand Island server instance.

  * Some of the `:connection` family of telemetry span events are emitted by the
  `ThousandIsland.Handler` implementation. If you use your own implementation in its place it is
  likely that such spans will not behave as expected.
  """

  @typedoc "The possible ways to indicate a timeout when returning values to Thousand Island"
  @type timeout_options :: timeout() | {:persistent, timeout()}

  @typedoc "The value returned by `c:handle_connection/2` and `c:handle_data/3`"
  @type handler_result ::
          {:continue, state :: term()}
          | {:continue, state :: term(), timeout_options() | {:continue, term()}}
          | {:switch_transport, {module(), upgrade_opts :: [term()]}, state :: term()}
          | {:switch_transport, {module(), upgrade_opts :: [term()]}, state :: term(),
             timeout_options() | {:continue, term()}}
          | {:close, state :: term()}
          | {:error, term(), state :: term()}

  @doc """
  This callback is called shortly after a client connection has been made, immediately after the socket handshake process has
  completed. It is called with the server's configured `handler_options` value as initial state. Handlers may choose to
  interact synchronously with the socket in this callback via calls to various `ThousandIsland.Socket` functions.

  The value returned by this callback causes Thousand Island to proceed in one of several ways:

  * Returning `{:close, state}` will cause Thousand Island to close the socket & call the `c:handle_close/2` callback to
  allow final cleanup to be done.
  * Returning `{:continue, state}` will cause Thousand Island to switch the socket to an asynchronous mode. When the
  client subsequently sends data (or if there is already unread data waiting from the client), Thousand Island will call
  `c:handle_data/3` to allow this data to be processed.
  * Returning `{:continue, state, timeout}` is identical to the previous case with the
  addition of a timeout. If `timeout` milliseconds passes with no data being received or messages
  being sent to the process, the socket will be closed and `c:handle_timeout/2` will be called.
  Note that this timeout is not persistent; it applies only to the interval until the next message
  is received. In order to set a persistent timeout for all future messages (essentially
  overwriting the value of `read_timeout` that was set at server startup), a value of
  `{:persistent, timeout}` may be returned.
  * Returning `{:continue, state, {:continue, continue}}` is identical to the previous case with the
  addition of a `c:GenServer.handle_continue/2` callback being made immediately after, in line with
  similar behaviour on `GenServer` callbacks.
  * Returning `{:switch_transport, {module, opts}, state}` will cause Thousand Island to try switching the transport of the
  current socket. The `module` should be an Elixir module that implements the `ThousandIsland.Transport` behaviour.
  Thousand Island will call `c:ThousandIsland.Transport.upgrade/2` for the given module to upgrade the transport in-place.
  After a successful upgrade Thousand Island will switch the socket to an asynchronous mode, as if `{:continue, state}`
  was returned. As with `:continue` return values, there are also timeout-specifying variants of
  this return value.
  * Returning `{:error, reason, state}` will cause Thousand Island to close the socket & call the `c:handle_error/3` callback to
  allow final cleanup to be done.
  """
  @callback handle_connection(socket :: ThousandIsland.Socket.t(), state :: term()) ::
              handler_result()

  @doc """
  This callback is called whenever client data is received after `c:handle_connection/2` or `c:handle_data/3` have returned an
  `{:continue, state}` tuple. The data received is passed as the first argument, and handlers may choose to interact
  synchronously with the socket in this callback via calls to various `ThousandIsland.Socket` functions.

  The value returned by this callback causes Thousand Island to proceed in one of several ways:

  * Returning `{:close, state}` will cause Thousand Island to close the socket & call the `c:handle_close/2` callback to
  allow final cleanup to be done.
  * Returning `{:continue, state}` will cause Thousand Island to switch the socket to an asynchronous mode. When the
  client subsequently sends data (or if there is already unread data waiting from the client), Thousand Island will call
  `c:handle_data/3` to allow this data to be processed.
  * Returning `{:continue, state, timeout}` is identical to the previous case with the
  addition of a timeout. If `timeout` milliseconds passes with no data being received or messages
  being sent to the process, the socket will be closed and `c:handle_timeout/2` will be called.
  Note that this timeout is not persistent; it applies only to the interval until the next message
  is received. In order to set a persistent timeout for all future messages (essentially
  overwriting the value of `read_timeout` that was set at server startup), a value of
  `{:persistent, timeout}` may be returned.
  * Returning `{:continue, state, {:continue, continue}}` is identical to the previous case with the
  addition of a `c:GenServer.handle_continue/2` callback being made immediately after, in line with
  similar behaviour on `GenServer` callbacks.
  * Returning `{:error, reason, state}` will cause Thousand Island to close the socket & call the `c:handle_error/3` callback to
  allow final cleanup to be done.
  """
  @callback handle_data(data :: binary(), socket :: ThousandIsland.Socket.t(), state :: term()) ::
              handler_result()

  @doc """
  This callback is called when the underlying socket is closed by the remote end; it should perform any cleanup required
  as it is the last callback called before the process backing this connection is terminated. The underlying socket
  has already been closed by the time this callback is called. The return value is ignored.

  This callback is not called if the connection is explicitly closed via `ThousandIsland.Socket.close/1`, however it
  will be called in cases where `handle_connection/2` or `handle_data/3` return a `{:close, state}` tuple.
  """
  @callback handle_close(socket :: ThousandIsland.Socket.t(), state :: term()) :: term()

  @doc """
  This callback is called when the underlying socket encounters an error; it should perform any cleanup required
  as it is the last callback called before the process backing this connection is terminated. The underlying socket
  has already been closed by the time this callback is called. The return value is ignored.

  In addition to socket level errors, this callback is also called in cases where `handle_connection/2` or `handle_data/3`
  return a `{:error, reason, state}` tuple, or when connection handshaking (typically TLS
  negotiation) fails.
  """
  @callback handle_error(reason :: any(), socket :: ThousandIsland.Socket.t(), state :: term()) ::
              term()

  @doc """
  This callback is called when the server process itself is being shut down; it should perform any cleanup required
  as it is the last callback called before the process backing this connection is terminated. The underlying socket
  has NOT been closed by the time this callback is called. The return value is ignored.

  This callback is only called when the shutdown reason is `:normal`, and is subject to the same caveats described
  in `c:GenServer.terminate/2`.
  """
  @callback handle_shutdown(socket :: ThousandIsland.Socket.t(), state :: term()) :: term()

  @doc """
  This callback is called when a handler process has gone more than `timeout` ms without receiving
  either remote data or a local message. The value used for `timeout` defaults to the
  `read_timeout` value specified at server startup, and may be overridden on a one-shot or
  persistent basis based on values returned from `c:handle_connection/2` or `c:handle_data/3`
  calls. Note that it is NOT called on explicit `ThousandIsland.Socket.recv/3` calls as they have
  their own timeout semantics. The underlying socket has NOT been closed by the time this callback
  is called. The return value is ignored.
  """
  @callback handle_timeout(socket :: ThousandIsland.Socket.t(), state :: term()) :: term()

  @optional_callbacks handle_connection: 2,
                      handle_data: 3,
                      handle_close: 2,
                      handle_error: 3,
                      handle_shutdown: 2,
                      handle_timeout: 2

  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour ThousandIsland.Handler

      use GenServer, restart: :temporary

      @spec start_link({handler_options :: term(), GenServer.options()}) :: GenServer.on_start()
      def start_link({handler_options, genserver_options}) do
        GenServer.start_link(__MODULE__, handler_options, genserver_options)
      end

      unquote(genserver_impl())
      unquote(handler_impl())
    end
  end

  @doc false
  defmacro add_handle_info_fallback(_module) do
    quote do
      def handle_info({msg, _raw_socket, _data}, _state) when msg in [:tcp, :ssl] do
        raise """
          The callback's `state` doesn't match the expected `{socket, state}` form.
          Please ensure that you are returning a `{socket, state}` tuple from any
          `GenServer.handle_*` callbacks you have implemented
        """
      end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def genserver_impl do
    quote do
      @impl true
      def init(handler_options) do
        Process.flag(:trap_exit, true)
        {:ok, {nil, handler_options}}
      end

      @impl true
      def handle_info(
            {:thousand_island_ready, raw_socket, server_config, acceptor_span, start_time},
            {nil, state}
          ) do
        {ip, port} =
          case server_config.transport_module.peername(raw_socket) do
            {:ok, remote_info} ->
              remote_info

            {:error, reason} ->
              # the socket has been prematurely closed by the client, we can't do anything with it
              # so we just close the socket, stop the GenServer with the error reason and move on.
              _ = server_config.transport_module.close(raw_socket)
              throw({:stop, {:shutdown, {:premature_conn_closing, reason}}, {raw_socket, state}})
          end

        span_meta = %{remote_address: ip, remote_port: port}

        connection_span =
          ThousandIsland.Telemetry.start_child_span(
            acceptor_span,
            :connection,
            %{monotonic_time: start_time},
            span_meta
          )

        socket = ThousandIsland.Socket.new(raw_socket, server_config, connection_span)
        ThousandIsland.Telemetry.span_event(connection_span, :ready)

        case ThousandIsland.Socket.handshake(socket) do
          {:ok, socket} -> {:noreply, {socket, state}, {:continue, :handle_connection}}
          {:error, reason} -> {:stop, {:shutdown, {:handshake, reason}}, {socket, state}}
        end
      catch
        {:stop, _, _} = stop -> stop
      end

      def handle_info(
            {msg, raw_socket, data},
            {%ThousandIsland.Socket{socket: raw_socket} = socket, state}
          )
          when msg in [:tcp, :ssl] do
        ThousandIsland.Telemetry.untimed_span_event(socket.span, :async_recv, %{data: data})

        __MODULE__.handle_data(data, socket, state)
        |> ThousandIsland.Handler.handle_continuation(socket)
      end

      def handle_info(
            {msg, raw_socket},
            {%ThousandIsland.Socket{socket: raw_socket} = socket, state}
          )
          when msg in [:tcp_closed, :ssl_closed] do
        {:stop, {:shutdown, :peer_closed}, {socket, state}}
      end

      def handle_info(
            {msg, raw_socket, reason},
            {%ThousandIsland.Socket{socket: raw_socket} = socket, state}
          )
          when msg in [:tcp_error, :ssl_error] do
        {:stop, reason, {socket, state}}
      end

      def handle_info(:timeout, {%ThousandIsland.Socket{} = socket, state}) do
        {:stop, {:shutdown, :timeout}, {socket, state}}
      end

      @before_compile {ThousandIsland.Handler, :add_handle_info_fallback}

      # Use a continue pattern here so that we have committed the socket
      # to state in case the `c:handle_connection/2` callback raises an error.
      # This ensures that the `c:terminate/2` calls below are able to properly
      # close down the process
      @impl true
      def handle_continue(:handle_connection, {%ThousandIsland.Socket{} = socket, state}) do
        __MODULE__.handle_connection(socket, state)
        |> ThousandIsland.Handler.handle_continuation(socket)
      end

      # Called if the remote end closed the connection before we could initialize it
      @impl true
      def terminate({:shutdown, {:premature_conn_closing, _reason}}, {_raw_socket, _state}) do
        :ok
      end

      # Called by GenServer if we hit our read_timeout. Socket is still open
      def terminate({:shutdown, :timeout}, {%ThousandIsland.Socket{} = socket, state}) do
        _ = __MODULE__.handle_timeout(socket, state)
        ThousandIsland.Handler.do_socket_close(socket, :timeout)
      end

      # Called if we're being shutdown in an orderly manner. Socket is still open
      def terminate(:shutdown, {%ThousandIsland.Socket{} = socket, state}) do
        _ = __MODULE__.handle_shutdown(socket, state)
        ThousandIsland.Handler.do_socket_close(socket, :shutdown)
      end

      # Called if the socket encountered an error during handshaking
      def terminate({:shutdown, {:handshake, reason}}, {%ThousandIsland.Socket{} = socket, state}) do
        _ = __MODULE__.handle_error(reason, socket, state)
        ThousandIsland.Handler.do_socket_close(socket, reason)
      end

      # Called if the socket encountered an error and we are configured to shutdown silently.
      # Socket is closed
      def terminate(
            {:shutdown, {:silent_termination, reason}},
            {%ThousandIsland.Socket{} = socket, state}
          ) do
        _ = __MODULE__.handle_error(reason, socket, state)
        ThousandIsland.Handler.do_socket_close(socket, reason)
      end

      # Called if the socket encountered an error during upgrading
      def terminate({:shutdown, {:upgrade, reason}}, {socket, state}) do
        _ = __MODULE__.handle_error(reason, socket, state)
        ThousandIsland.Handler.do_socket_close(socket, reason)
      end

      # Called if the remote end shut down the connection, or if the local end closed the
      # connection by returning a `{:close,...}` tuple (in which case the socket will be open)
      def terminate({:shutdown, reason}, {%ThousandIsland.Socket{} = socket, state}) do
        _ = __MODULE__.handle_close(socket, state)
        ThousandIsland.Handler.do_socket_close(socket, reason)
      end

      # Called if the socket encountered an error. Socket is closed
      def terminate(reason, {%ThousandIsland.Socket{} = socket, state}) do
        _ = __MODULE__.handle_error(reason, socket, state)
        ThousandIsland.Handler.do_socket_close(socket, reason)
      end

      # This clause could happen if we do not have a socket defined in state (either because the
      # process crashed before setting it up, or because the user sent an invalid state)
      def terminate(_reason, _state) do
        :ok
      end
    end
  end

  def handler_impl do
    quote do
      @impl true
      def handle_connection(_socket, state), do: {:continue, state}

      @impl true
      def handle_data(_data, _socket, state), do: {:continue, state}

      @impl true
      def handle_close(_socket, _state), do: :ok

      @impl true
      def handle_error(_error, _socket, _state), do: :ok

      @impl true
      def handle_shutdown(_socket, _state), do: :ok

      @impl true
      def handle_timeout(_socket, _state), do: :ok

      defoverridable ThousandIsland.Handler
    end
  end

  @spec do_socket_close(
          ThousandIsland.Socket.t(),
          reason :: :shutdown | :local_closed | term()
        ) :: :ok
  @doc false
  def do_socket_close(socket, reason) do
    measurements =
      case ThousandIsland.Socket.getstat(socket) do
        {:ok, stats} ->
          stats
          |> Keyword.take([:send_oct, :send_cnt, :recv_oct, :recv_cnt])
          |> Enum.into(%{})

        _ ->
          %{}
      end

    metadata =
      if reason in [:shutdown, :local_closed, :peer_closed], do: %{}, else: %{error: reason}

    _ = ThousandIsland.Socket.close(socket)
    ThousandIsland.Telemetry.stop_span(socket.span, measurements, metadata)
  end

  @doc false
  def handle_continuation(continuation, socket) do
    case continuation do
      {:continue, state} ->
        _ = ThousandIsland.Socket.setopts(socket, active: :once)
        {:noreply, {socket, state}, socket.read_timeout}

      {:continue, state, {:continue, continue}} ->
        _ = ThousandIsland.Socket.setopts(socket, active: :once)
        {:noreply, {socket, state}, {:continue, continue}}

      {:continue, state, {:persistent, timeout}} ->
        socket = %{socket | read_timeout: timeout}
        _ = ThousandIsland.Socket.setopts(socket, active: :once)
        {:noreply, {socket, state}, timeout}

      {:continue, state, timeout} ->
        _ = ThousandIsland.Socket.setopts(socket, active: :once)
        {:noreply, {socket, state}, timeout}

      {:switch_transport, {module, upgrade_opts}, state} ->
        handle_switch_continuation(socket, module, upgrade_opts, state, socket.read_timeout)

      {:switch_transport, {module, upgrade_opts}, state, {:continue, continue}} ->
        handle_switch_continuation(socket, module, upgrade_opts, state, {:continue, continue})

      {:switch_transport, {module, upgrade_opts}, state, {:persistent, timeout}} ->
        socket = %{socket | read_timeout: timeout}
        handle_switch_continuation(socket, module, upgrade_opts, state, timeout)

      {:switch_transport, {module, upgrade_opts}, state, timeout} ->
        handle_switch_continuation(socket, module, upgrade_opts, state, timeout)

      {:close, state} ->
        {:stop, {:shutdown, :local_closed}, {socket, state}}

      {:error, :timeout, state} ->
        {:stop, {:shutdown, :timeout}, {socket, state}}

      {:error, reason, state} ->
        if socket.silent_terminate_on_error do
          {:stop, {:shutdown, {:silent_termination, reason}}, {socket, state}}
        else
          {:stop, reason, {socket, state}}
        end
    end
  end

  defp handle_switch_continuation(socket, module, upgrade_opts, state, timeout_or_continue) do
    case ThousandIsland.Socket.upgrade(socket, module, upgrade_opts) do
      {:ok, socket} ->
        _ = ThousandIsland.Socket.setopts(socket, active: :once)
        {:noreply, {socket, state}, timeout_or_continue}

      {:error, reason} ->
        {:stop, {:shutdown, {:upgrade, reason}}, {socket, state}}
    end
  end
end
