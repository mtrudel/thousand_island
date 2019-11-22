defmodule ThousandIsland.ConnectionWorker do
  use Task

  alias ThousandIsland.Socket

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run({transport_socket, transport_module, handler_module, handler_opts}) do
    connection_id = UUID.uuid4()

    :telemetry.execute([:connection, :handler, :start], %{}, %{
      connection_id: connection_id,
      handler_module: handler_module,
      handler_opts: handler_opts
    })

    socket = Socket.new(transport_socket, transport_module, connection_id)
    start = System.monotonic_time()

    try do
      handler_module.handle_connection(socket, handler_opts)
      duration = System.monotonic_time() - start

      :telemetry.execute([:connection, :handler, :complete], %{duration: duration}, %{
        connection_id: connection_id,
        handler_module: handler_module,
        handler_opts: handler_opts
      })
    rescue
      exception ->
        :telemetry.execute([:connection, :handler, :exception], %{exception: exception, stacktrace: __STACKTRACE__}, %{
          connection_id: connection_id,
          handler_module: handler_module,
          handler_opts: handler_opts
        })
    after
      Socket.close(socket)
    end
  end
end
