defmodule ThousandIsland.Handlers.Info do
  @moduledoc false

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    peer_info = ThousandIsland.Socket.peer_info(socket)
    local_info = ThousandIsland.Socket.local_info(socket)
    ThousandIsland.Socket.send(socket, "#{inspect([local_info, peer_info])}")
    {:ok, :close, state}
  end
end
