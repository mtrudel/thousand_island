defmodule ThousandIsland.Handlers.Info do
  @moduledoc false

  alias ThousandIsland.{Handler, Socket}

  @behaviour Handler

  @impl Handler
  def handle_connection(socket, _opts) do
    peer_info = Socket.peer_info(socket)
    local_info = Socket.local_info(socket)
    Socket.send(socket, "#{inspect([local_info, peer_info])}")
  end
end
