defmodule ThousandIsland.ConnectionWorker do
  use Task

  alias ThousandIsland.Socket

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run({transport_socket, transport_module, handler_module, handler_opts}) do
    socket = Socket.new(transport_socket, transport_module)

    try do
      handler_module.handle_connection(socket, handler_opts)
    after
      Socket.close(socket)
    end
  end
end
