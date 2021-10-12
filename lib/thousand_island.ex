defmodule ThousandIsland do
  @moduledoc """
  Thousand Island is a modern, pure Elixir socket server, inspired heavily by
  [ranch](https://github.com/ninenines/ranch). It aims to be easy to understand
  & reason about, while also being at least as stable and performant as alternatives.

  Thousand Island is implemented as a supervision tree which is intended to be hosted
  inside a host application, often as a dependency embedded within a higher-level
  protocol library such as [Bandit](https://github.com/mtrudel/bandit). Aside from
  supervising the Thousand Island process tree, applications interact with Thousand
  Island primarily via the `ThousandIsland.Handler` behaviour.

  ## Handlers

  The `ThousandIsland.Handler` behaviour defines the interface that Thousand Island
  uses to pass `ThousandIsland.Socket`s up to the application level; together they
  form the primary interface that most applications will have with Thousand Island.
  Thousand Island comes with a few simple protocol handlers to serve as examples;
  these can be found in the [examples](https://github.com/mtrudel/thousand_island/tree/main/examples)
  folder of this project. A simple implementation would look like this:

  ```elixir
  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  {:ok, pid} = ThousandIsland.start_link(port: 1234, handler_module: Echo)
  ```

  For more information, please consult the `ThousandIsland.Handler` documentation.

  ## Starting a Thousand Island Server

  A typical use of `ThousandIsland` might look like the following: 

  ```elixir
  defmodule MyApp.Supervisor do
    # ... other Supervisor boilerplate

    def init(config) do
      children = [
        # ... other children as dictated by your app
        {ThousandIsland, port: 1234, handler_module: MyApp.ConnectionHandler}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
  ```

  You can also start servers directly via the `start_link/1` function:

  ```elixir
  {:ok, pid} = ThousandIsland.start_link(port: 1234, handler_module: MyApp.ConnectionHandler)
  ```

  ## Configuration

  A number of options are defined when starting a server. The complete list is
  defined by the `t:ThousandIsland.options/0` type.

  ## Connection Draining & Shutdown

  `ThousandIsland` instances are just a process tree consisting of standard
  Supervisor, GenServer and Task modules, and so the usual rules regarding
  shutdown and shutdown timeouts apply. Immediately upon beginning the shutdown
  sequence the ThousandIsland.ShutdownListener process will cause the listening socket
  to shut down, which in turn will cause all of the `Acceptor` processes to shut
  down as well. At this point all that is left in the supervision tree are several
  layers of Supervisors and whatever `Handler` processes were in progress when
  shutdown was initiated. At this point, standard Supervisor shutdown timeout
  semantics give existing connections a chance to finish things up. `Handler`
  processes trap exit, so they continue running beyond shutdown until they either
  complete or are `:brutal_kill`ed after their shutdown timeout expires.

  ## Logging & Telemetry

  As a low-level library, Thousand Island purposely does not do any inline 
  logging of any kind. The `ThousandIsland.Logging` module defines a number of
  functions to aid in tracing connections at various log levels, and such logging
  can be dynamically enabled and disabled against an already running server. This
  logging is backed by `:telemetry` events internally, and if desired these events
  can also be hooked by your application for logging or metric purposes. The following is a complete list of events emitted by Thousand Island:

  * `[:listener, :start]`: Emitted when the server successfully listens on the configured port.
  * `[:listener, :error]`: Emitted when the server encounters an error listening on the configured port.
  * `[:listener, :shutdown]`: Emitted when the server shuts down.
  * `[:acceptor, :start]`: Emitted when an acceptor process starts up.
  * `[:acceptor, :accept]`: Emitted when an acceptor process accepts a new client connection.
  * `[:acceptor, :shutdown]`: Emitted when an acceptor process shuts down.
  * `[:handler, :start]`: Emitted whenever a `ThousandIsland.Handler` process is made ready
  * `[:handler, :async_recv]`: Emitted whenever a `ThousandIsland.Handler` process receives data asynchronously
  * `[:handler, :shutdown]`: Emitted whenever a `ThousandIsland.Handler` process terminates
  * `[:handler, :error]`: Emitted whenever a `ThousandIsland.Handler` process shuts down due to error
  * `[:socket, :handshake]`: Emitted whenever a `ThousandIsland.Socket.handshake/1` call completes.
  * `[:socket, :handshake_error]`: Emitted whenever a `ThousandIsland.Socket.handshake/1` call errors.
  * `[:socket, :recv]`: Emitted whenever a `ThousandIsland.Socket.recv/3` call completes.
  * `[:socket, :send]`: Emitted whenever a `ThousandIsland.Socket.send/2` call completes.
  * `[:socket, :sendfile]`: Emitted whenever a `ThousandIsland.Socket.sendfile/4` call completes.
  * `[:socket, :shutdown]`: Emitted whenever a `ThousandIsland.Socket.shutdown/2` call completes.
  * `[:socket, :close]`: Emitted whenever a `ThousandIsland.Socket.close/1` call completes.

  Where meaurements indicate a time duration they are are expressed in `System` 
  `:native` units for performance reasons. They can be conveted to any desired 
  time unit via `System.convert_time_unit/3`.
  """

  @typedoc """
  Possible options to configure a server. Valid option values are as follows:

  * `handler_module`: The name of the module used to handle connections to this server.
  The module is expected to implement the `ThousandIsland.Handler` behaviour. Required.
  * `handler_options`: A term which is passed as the initial state value to 
  `c:ThousandIsland.Handler.handle_connection/2` calls. Optional, defaulting to nil.
  * `port`: The TCP port number to listen on. If not specified this defaults to 4000.
  If a port number of `0` is given, the server will dynamically assign a port number
  which can then be obtained via `local_port/1`.
  * `transport_module`: The name of the module which provides basic socket functions.
  Thousand Island provides `ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL`,
  which provide clear and TLS encrypted TCP sockets respectively. If not specified this
  defaults to `ThousandIsland.Transports.TCP`.
  * `transport_options`: A keyword list of options to be passed to the transport module's
  `c:ThousandIsland.Transport.listen/2` function. Valid values depend on the transport
  module specified in `transport_module` and can be found in the documentation for the
  `ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL` modules. Any options
  in terms of interfaces to listen to / certificates and keys to use for SSL connections 
  will be passed in via this option.
  * `num_acceptors`: The numbner of acceptor processes to run. Defaults to 10.
  """
  @type options :: [
          handler_module: module(),
          handler_options: term(),
          port: :inet.port_number(),
          transport_module: module(),
          transport_options: keyword(),
          num_acceptors: pos_integer()
        ]

  alias ThousandIsland.{Listener, Server, ServerConfig}

  @doc false
  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Starts a `ThousandIsland` instance with the given options. Returns a pid
  that can be used to further manipulate the server via other functions defined on
  this module in the case of success, or an error tuple describing the reason the
  server was unable to start in the case of failure.
  """
  @spec start_link(options()) :: {:ok, pid} | {:error, term}
  def start_link(opts \\ []) do
    opts
    |> ServerConfig.new()
    |> Server.start_link()
  end

  @doc """
  Returns the local port number that the servrer is listening on.
  """
  @spec local_port(pid()) :: {:ok, :inet.port_number()}
  def local_port(pid) do
    pid |> Server.listener_pid() |> Listener.listener_port()
  end

  @doc """
  Synchronously stops the given server, waiting up to the given number of milliseconds 
  for existing connections to finish up. Immediately upon calling this function, 
  the server stops listening for new connections, and then proceeds to wait until
  either all existing connections have completed or the specified timeout has 
  elapsed.
  """
  @spec stop(pid(), timeout()) :: :ok
  def stop(pid, connection_wait \\ 15_000) do
    Supervisor.stop(pid, :normal, connection_wait)
  end
end
