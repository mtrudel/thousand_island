defmodule ThousandIsland.Handlers.Exploding do
  @moduledoc false

  alias ThousandIsland.Handler

  @behaviour Handler

  @impl Handler
  def handle_connection(_socket, _opts) do
    raise "boom"
  end
end
