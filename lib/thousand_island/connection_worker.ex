defmodule ThousandIsland.ConnectionWorker do
  use Task

  require Logger

  alias ThousandIsland.Socket

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run({transport_socket, transport_module, handler_module, handler_opts}) do
    socket = Socket.new(transport_socket, transport_module)

    try do
      handler_module.handle_connection(socket, handler_opts)
    rescue
      exception ->
        Logger.error(Exception.format(:error, exception, __STACKTRACE__))
    after
      Socket.close(socket)
    end
  end
end
