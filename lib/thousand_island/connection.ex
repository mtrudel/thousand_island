defmodule ThousandIsland.Connection do
  use GenServer, restart: :transient

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def start_connection(pid) do
    GenServer.cast(pid, :start_connection)
  end

  def init(arg) do
    created = System.monotonic_time()
    {:ok, {arg, created}}
  end

  def handle_cast(
        :start_connection,
        {{transport_socket,
          %ThousandIsland.ServerConfig{
            transport_module: transport_module,
            handler_module: handler_module,
            handler_opts: handler_opts
          } = server_config} = state, created}
      ) do
    connection_info = %{
      connection_id: UUID.uuid4(),
      server_config: server_config
    }

    start = System.monotonic_time()
    telemetry(:start, %{}, connection_info)

    case transport_module.handshake(transport_socket) do
      {:ok, transport_socket} ->
        try do
          negotiated = System.monotonic_time()

          transport_socket
          |> ThousandIsland.Socket.new(connection_info)
          |> handler_module.handle_connection(handler_opts)

          duration = System.monotonic_time() - negotiated
          handshake = negotiated - start
          startup = start - created

          telemetry(
            :complete,
            %{duration: duration, handshake: handshake, startup: startup},
            connection_info
          )
        rescue
          e -> telemetry(:exception, %{exception: e, stacktrace: __STACKTRACE__}, connection_info)
        end

      {:error, reason} ->
        handshake = System.monotonic_time() - start
        telemetry(:handshake_error, %{handshake: handshake, reason: reason}, connection_info)
    end

    {:stop, :normal, state}
  end

  def terminate(
        _reason,
        {transport_socket, %ThousandIsland.ServerConfig{transport_module: transport_module}}
      ) do
    transport_module.close(transport_socket)
  end

  defp telemetry(subevent, measurement, connection_info) do
    :telemetry.execute([:connection, :handler] ++ [subevent], measurement, connection_info)
  end
end
