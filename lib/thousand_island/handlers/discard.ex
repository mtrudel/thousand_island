defmodule ThousandIsland.Handlers.Discard do
  @moduledoc """
  A sample Handler implementation of the Discard protocol

  https://en.wikipedia.org/wiki/Discard_Protocol
  """

  alias ThousandIsland.{Socket, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(conn, _opts) do
    consume(conn)
  end

  defp consume(conn) do
    Socket.recv(conn)
    consume(conn)
  end
end
