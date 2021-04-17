defmodule ThousandIsland.Handlers.Sendfile do
  @moduledoc false

  @behaviour ThousandIsland.Handler

  use Task

  alias ThousandIsland.{Handler, Socket}

  @impl Handler
  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    {:ok, socket} = Socket.get_socket()
    Socket.sendfile(socket, Path.join(__DIR__, "sendfile"), 0, 6)
    Socket.sendfile(socket, Path.join(__DIR__, "sendfile"), 1, 3)
  end
end
