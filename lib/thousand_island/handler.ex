defmodule ThousandIsland.Handler do
  @moduledoc """
  `ThousandIsland.Handler` defines the behaviour required of the application layer of a Thousand Island server. When starting a
  Thousand Island server, you must pass the name of a module implementing this behaviour as the `handler_module` parameter.
  Thousand Island will then use the specified module to handle each connection that is made to the server.

  The lifecycle of a Handler instance is as follows:

  1. After a client connection to a Thousand Island server is made, Thousand Island will complete the initial setup of the 
  connection (performing a TLS handshake, for example), and then call `c:handle_connection/2`.

  2. A handler implementation may choose to process a client connection within the `c:handle_connection/2` function by
  calling functions against the passed `ThousandIsland.Socket`. In many cases, this may be all that may be required of
  an implementation & the value `{:ok, :close, state}` can be returned which will cause Thousand Island to close the connection
  to the client.

  3. In cases where the server wishes to keep the connection open and wait for subsequent requests from the client on the 
  same socket, it may elect to return `{:ok, :continue, state}`. This will cause Thousand Island to wait for client data
  asynchronously; `c:handle_data/3` will be invoked when the client sends more data. 

  4. In the meantime, the process which is hosting connection is idle & able to receive messages sent from elsewhere in your
  application as needed. The implementation included in the `use ThousandIsland.Handler` macro uses a `GenServer` structure,
  so you may implement such behaviour via standard `GenServer` patterns. Note that in these cases that state is provided (and
  must be returned) in a `{socket, state}` format, where the second tuple is the same state value that is passed to the various `handle_*` callbacks
  defined on this behaviour.

  It is fully supported to intermix synchronous `ThousandIsland.Socket.recv` calls with async return values from `c:handle_connection/2`
  and `c:handle_data/3` callbacks. 

  # Example 

  A simple example of a Hello World server is as follows:

  ```elixir
  defmodule ThousandIsland.Handlers.HelloWorld do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      ThousandIsland.Socket.send(socket, "Hello, World")
      {:ok, :close, state}
    end
  end
  ```

  Another example of a server that echoes back all data sent to it is as follows:

  ```elixir
  defmodule ThousandIsland.Handlers.Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:ok, :continue, state}
    end
  end
  ```

  Note that in this example there is no `c:handle_connection/2` callback defined. The default implementation of this
  callback will simply return `{:ok, :continue, state}`, which is appropriate for cases where the client is the first 
  party to communicate.

  Another example of a server which can send and receive messages asynchronously is as follows:

  ```elixir
  defmodule ThousandIsland.Handlers.Messenger do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(msg, _socket, state) do
      IO.puts(msg)
      {:ok, :continue, state}
    end

    def handle_info({:send, msg}, {socket, state}) do
      ThousandIsland.Socket.send(socket, msg)
      {:noreply, {socket, state}}
    end
  end
  ```

  Note that in this example we make use of the fact that the handler process is really just a GenServer to send it messages
  which are able to make use of the underlying socket. This allows for bidirectional sending and receiving of messages in
  an asynchronous manner.

  # When Handler Isn't Enough

  The `use ThousandIsland.Handler` implementation should be flexible enough to power just about any handler, however if
  this should not be the case for you, there is an escape hatch available. If you require more flexibility than the
  `ThousandIsland.Handler` behaviour provides, you are free to specify any module which implements `start_link/1` as the
  `handler_module` parameter. The process of getting from this new process to a ready-to-use socket is somewhat
  delicate, however. The steps required are as follows:

  1. Thousand Island calls `start_link/1` on the configured `handler_module`, passing in the configured
  `handler_options` as the sole argument. This function is expected to return a conventional `GenServer.on_start()`
  style tuple. Note that this newly created process is not passed the connection socket immediately.
  2. The socket will be passed to the new process via a message of the form `{:thousand_island_ready, socket}`.
  3. Once the process receives the socket, it must call `ThousandIsland.Socket.handshake/1` with the socket as the sole
  argument in order to finalize the setup of the socket.
  4. The socket is now ready to use.

  In addition to this process, there are several other considerations to be aware of:

  * The underlying socket is closed automatically when the handler process ends.

  * Handler processes should have a restart strategy of `:temporary` to ensure that Thousand Island does not attempt to
  restart crashed handlers.

  * Handler processes should trap exit if possible so that existing connections can be given a chance to cleanly shut
  down when shutting down a Thousand Island server instance.

  * The `:handler` family of telemetry events are emitted by the `ThousandIsland.Handler` implementation. If you use your
  own implementation in its place you will not see any such telemetry events.
  """

  @typedoc """
  The value returned by `c:handle_connection/2` and `c:handle_data/3`
  """
  @type handler_result ::
          {:ok, :continue, state :: term()}
          | {:ok, :continue, state :: term(), timeout()}
          | {:ok, :close, state :: term()}
          | {:error, String.t(), state :: term()}

  @doc """
  This function is called shortly after a client connection has been made, immediately after the socket handshake process has
  completed. It is called with the server's configured `handler_options` value as initial state. Handlers may choose to
  interact synchronously with the socket in this function via calls to various `ThousandIsland.Socket` functions.

  The value returned by this callback causes Thousand Island to proceed in once of several ways:

  * Returning `{:ok, :close, state}` will cause Thousand Island to close the socket & call the `c:handle_close/2` function to 
  allow final cleanup to be done.
  * Returning `{:ok, :continue, state}` will cause Thousand Island to switch the socket to an asynchronous mode. When the 
  client subsequently sends data (or if there is already unread data waiting from the client), Thousand Island will call
  `c:handle_data/3` to allow this data to be processed.
  * Returning `{:error, reason, state}` will cause Thousand Island to close the socket & call the `c:handle_error/3` function to 
  allow final cleanup to be done.
  """
  @callback handle_connection(socket :: ThousandIsland.Socket.t(), state :: term()) ::
              handler_result()

  @doc """
  This function is called whenever client data is received after `c:handle_connection/2` or `c:handle_data/3` have returned an
  `{:ok, :continue, state}` tuple. The data received is passed as the first argument, and handlers may choose to interact 
  synchronously with the socket in this function via calls to various `ThousandIsland.Socket` functions.

  The value returned by this callback causes Thousand Island to proceed in once of several ways:

  * Returning `{:ok, :close, state}` will cause Thousand Island to close the socket & call the `c:handle_close/2` function to 
  allow final cleanup to be done.
  * Returning `{:ok, :continue, state}` will cause Thousand Island to switch the socket to an asynchronous mode. When the 
  client subsequently sends data (or if there is already unread data waiting from the client), Thousand Island will call
  `c:handle_data/3` to allow this data to be processed.
  * Returning `{:error, reason, state}` will cause Thousand Island to close the socket & call the `c:handle_error/3` function to 
  allow final cleanup to be done.
  """
  @callback handle_data(data :: binary(), socket :: ThousandIsland.Socket.t(), state :: term()) ::
              handler_result()

  @doc """
  This function is called when the underlying socket is closed by the remote end; it should perform any cleanup required
  as it is the last function called before the process backing this connection is terminated. The return value is ignored.

  This function is not called if the connection is explicitly closed at this end, however it will be called in cases where
  `handle_connection/2` or `handle_data/3` return a `{:ok, :close, state}` tuple.
  """
  @callback handle_close(socket :: ThousandIsland.Socket.t(), state :: term()) :: term()

  @doc """
  This function is called when the underlying socket encounters an error; it should perform any cleanup required
  as it is the last function called before the process backing this connection is terminated. The return value is ignored.

  In addition to socket level errors, this function is also called ifn cases where `handle_connection/2` or `handle_data/3`
  return a `{:ok, :close, state}` tuple.
  """
  @callback handle_error(
              reason :: String.t(),
              socket :: ThousandIsland.Socket.t(),
              state :: term()
            ) ::
              term()

  @optional_callbacks handle_connection: 2, handle_data: 3, handle_close: 2, handle_error: 3

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour ThousandIsland.Handler

      use GenServer, restart: :temporary

      # Dialyzer gets confused by handle_continuation being a defp and not a def
      @dialyzer {:no_match, handle_continuation: 2}

      def handle_connection(_socket, state), do: {:ok, :continue, state}
      def handle_data(_data, _socket, state), do: {:ok, :continue, state}
      def handle_close(_socket, _state), do: :ok
      def handle_error(_error, _socket, _state), do: :ok

      defoverridable ThousandIsland.Handler

      def start_link(arg) do
        GenServer.start_link(__MODULE__, arg)
      end

      @impl GenServer
      def init(handler_options) do
        Process.flag(:trap_exit, true)
        {:ok, {nil, handler_options}}
      end

      @impl GenServer
      def handle_info({:thousand_island_ready, socket}, {_, state}) do
        :telemetry.execute([:handler, :start], %{}, %{
          connection_id: socket.connection_id,
          acceptor_id: socket.acceptor_id
        })

        ThousandIsland.Socket.handshake(socket)
        {:noreply, {socket, state}, {:continue, :handle_connection}}
      end

      # Use a continue pattern here so that we have committed the socket
      # to state in case the `c:handle_connection/2` callback raises an error.
      # This ensures that the `c:terminate/2` calls below are able to properly
      # close down the process
      @impl GenServer
      def handle_continue(:handle_connection, {socket, state}) do
        __MODULE__.handle_connection(socket, state)
        |> handle_continuation(socket)
      end

      def handle_info({msg, _, data}, {socket, state}) when msg in [:tcp, :ssl] do
        :telemetry.execute([:handler, :async_recv], %{data: data}, %{
          connection_id: socket.connection_id
        })

        __MODULE__.handle_data(data, socket, state)
        |> handle_continuation(socket)
      end

      def handle_info({msg, _}, {socket, state}) when msg in [:tcp_closed, :ssl_closed] do
        {:stop, :shutdown, {socket, state}}
      end

      def handle_info({msg, _, reason}, {socket, state}) when msg in [:tcp_error, :ssl_error] do
        {:stop, reason, {socket, state}}
      end

      def handle_info(:timeout, {socket, state}) do
        {:stop, :timeout, {socket, state}}
      end

      @impl GenServer
      def terminate(:shutdown, {socket, state}) do
        ThousandIsland.Socket.close(socket)

        :telemetry.execute([:handler, :shutdown], %{}, %{connection_id: socket.connection_id})

        __MODULE__.handle_close(socket, state)
      end

      def terminate(reason, {socket, state}) do
        ThousandIsland.Socket.close(socket)

        :telemetry.execute([:handler, :error], %{error: reason}, %{
          connection_id: socket.connection_id
        })

        __MODULE__.handle_error(reason, socket, state)
      end

      defp handle_continuation(continuation, socket) do
        case continuation do
          {:ok, :continue, state} ->
            ThousandIsland.Socket.setopts(socket, active: :once)
            {:noreply, {socket, state}}

          {:ok, :continue, state, timeout} ->
            ThousandIsland.Socket.setopts(socket, active: :once)
            {:noreply, {socket, state}, timeout}

          {:ok, :close, state} ->
            {:stop, :shutdown, {socket, state}}

          {:error, reason, state} ->
            {:stop, reason, {socket, state}}
        end
      end
    end
  end
end
