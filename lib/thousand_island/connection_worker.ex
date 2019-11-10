defmodule ThousandIsland.ConnectionWorker do
  use Task

  require Logger

  alias ThousandIsland.Connection

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run({socket, opts}) do
    conn = Connection.new(socket, opts)

    try do
      Logger.debug("Connection #{inspect(self())} starting up")

      Connection.recv(conn)
      Connection.send(conn, "HTTP/1.1 200\r\n\r\nHello")

      Logger.debug("Connection #{inspect(self())} shutting down")
    after
      Connection.close(conn)
    end
  end
end
