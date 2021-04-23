defmodule ThousandIsland.Handlers.Sendfile do
  @moduledoc false

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    ThousandIsland.Socket.sendfile(socket, Path.join(__DIR__, "sendfile"), 0, 6)
    ThousandIsland.Socket.sendfile(socket, Path.join(__DIR__, "sendfile"), 1, 3)
    {:ok, :close, state}
  end
end
