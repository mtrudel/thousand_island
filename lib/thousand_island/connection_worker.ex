defmodule ThousandIsland.ConnectionWorker do
  use Task

  alias ThousandIsland.Socket

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run({socket, transport_module, handler_module, handler_opts}) do
    conn = Socket.new(socket, transport_module)

    try do
      handler_module.handle_connection(conn, handler_opts)
    after
      Socket.close(conn)
    end
  end
end
