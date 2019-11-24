defmodule ThousandIsland.ConnectionWorker do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(
        {transport_socket,
         %ThousandIsland.ServerConfig{
           transport_module: transport_module,
           handler_module: handler_module,
           handler_opts: handler_opts
         } = server_config}
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
          telemetry(:complete, %{duration: duration, handshake: handshake}, connection_info)
        rescue
          e -> telemetry(:exception, %{exception: e, stacktrace: __STACKTRACE__}, connection_info)
        end

      {:error, reason} ->
        handshake = System.monotonic_time() - start
        telemetry(:handshake_error, %{handshake: handshake, reason: reason}, connection_info)
    end

    transport_module.close(transport_socket)
  end

  defp telemetry(subevent, measurement, connection_info) do
    :telemetry.execute([:connection, :handler] ++ [subevent], measurement, connection_info)
  end
end
