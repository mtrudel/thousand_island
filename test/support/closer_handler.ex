defmodule ThousandIsland.Handlers.Closer do
  @moduledoc false

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    ThousandIsland.Socket.close(socket)
    {:ok, :close, state}
  end
end
