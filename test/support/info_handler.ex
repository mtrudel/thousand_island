defmodule ThousandIsland.Handlers.Info do
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
    peer_info = Socket.peer_info(socket)
    local_info = Socket.local_info(socket)
    Socket.send(socket, "#{inspect([local_info, peer_info])}")
  end
end
