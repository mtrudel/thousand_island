defmodule ThousandIsland.Handlers.SyncEcho do
  @moduledoc false

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    {:ok, data} = ThousandIsland.Socket.recv(socket)
    ThousandIsland.Socket.send(socket, data)
    {:ok, :close, state}
  end
end
