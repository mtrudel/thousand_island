defmodule ThousandIsland.Handlers.Exploding do
  @moduledoc false

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(_socket, _state) do
    raise "boom"
  end
end
