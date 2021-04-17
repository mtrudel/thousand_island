defmodule ThousandIsland.Handler do
  @moduledoc """
  Defines the behaviour required of the application layer of a Thousand Island
  server. Users pass the name of a module implementing this behaviour as the
  `handler_module` parameter when starting a server instance, and Thousand Island
  will call this module's `c:start_link/1` function every time a client connects
  to the server. The process returned from this call is added to a Thousand Island
  managed supervisor.

  This newly created process is not passed the connection socket immediately. Before
  the connection socket can be used, two things must happen:

  1. Thousand Island must make this newly created process the controlling process
  for the socket.
  2. The newly created process must call `ThousandIsland.Socket.handshake/1` on
  the socket.

  This procedure is a bit delicate and has been wrapped up in a few helpers to make
  common patterns easy to implement. Because this procedure relies on messages under
  the covers, using these helpers safely differs somewhat depending on if you are
  implementing a GenServer based handler or not.

  #### Task based handlers

  For handlers which are Task based (or otherwise do not manage message delivery
  on your behalf), your handler should make a call to `ThousandIsland.Socket.get_socket/0`
  as soon as it is ready to start handling connections. This call will return the
  connection socket, ready for use. An example follows:

  ```elixir
  defmodule Echo do
    @behaviour ThousandIsland.Handler

    use Task

    @impl ThousandIsland.Handler
    def start_link(arg) do
      Task.start_link(__MODULE__, :run, [arg])
    end

    def run(_arg) do
      {:ok, socket} = ThousandIsland.Socket.get_socket()
      {:ok, req} = ThousandIsland.Socket.recv(socket)
      ThousandIsland.Socket.send(socket, req)
    end
  end
  ```

  Note that the `ThousandIsland.Socket.get_socket/0` function uses `receive` to directly
  wait on the process' mailbox, and as such is not apporpriate for use in a GenServer process.

  #### GenServer based handlers

  For handlers which are GenServer based (or otherwise manage message delivery
  on your behalf), your handler will need to arrange for the receipt of a specific
  message which contains your connection socket. This connection socket passed in
  this message has had its ownership transferred to the handler process, but has
  not yet undergone a handshake with the remote end (this must be done within
  the handler process). An example follows:

  ```elixir
  defmodule Echo do
    @behaviour ThousandIsland.Handler

    use GenServer, restart: :temporary

    @impl ThousandIsland.Handler
    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(_args) do
      {:ok, nil}
    end

    def handle_info({:thousand_island_ready, socket}, state) do
      # The passed in socket has been transferred to this process, but has not yet done a handshake
      ThousandIsland.Socket.handshake(socket)
      # The socket is now ready to use
      {:ok, req} = ThousandIsland.Socket.recv(socket)
      ThousandIsland.Socket.send(socket, req)
      {:stop, :shutdown, state}
    end
  end
  ```

  Note that it is important for your task to have a restart strategy of `temporary`.

  The underlying socket is closed automatically when the handler process ends.
  """

  @doc """
  Called by Thousand Island once for every client connection.

  The argument consists of an arbitrary term specified via the
  `handler_options` parameter at server start time.
  """
  @callback start_link(term()) :: Supervisor.on_start()
end
