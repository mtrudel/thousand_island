defmodule ThousandIsland.ConnectionWorker do
  use Task

  alias ThousandIsland.{ServerConfig, Socket}

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run(
        {transport_socket,
         %ServerConfig{handler_module: handler_module, handler_opts: handler_opts} = server_config}
      ) do
    connection_info = %{
      connection_id: UUID.uuid4(),
      server_config: server_config
    }

    start = System.monotonic_time()
    telemetry(:start, %{}, connection_info)
    socket = Socket.new(transport_socket, connection_info)

    try do
      handler_module.handle_connection(socket, handler_opts)
      duration = System.monotonic_time() - start
      telemetry(:complete, %{duration: duration}, connection_info)
    rescue
      e -> telemetry(:exception, %{exception: e, stacktrace: __STACKTRACE__}, connection_info)
    after
      Socket.close(socket)
    end
  end

  defp telemetry(subevent, measurement, connection_info) do
    :telemetry.execute([:connection, :handler] ++ [subevent], measurement, connection_info)
  end
end
