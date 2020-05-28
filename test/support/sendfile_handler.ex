defmodule ThousandIsland.Handlers.Sendfile do
  @moduledoc false

  alias ThousandIsland.{Handler, Socket}

  @behaviour Handler

  @impl Handler
  def handle_connection(socket, _opts) do
    Socket.sendfile(socket, Path.join(__DIR__, "sendfile"), 0, 6)
    Socket.sendfile(socket, Path.join(__DIR__, "sendfile"), 1, 3)
  end
end
