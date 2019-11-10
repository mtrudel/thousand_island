defmodule ThousandIsland.Handlers.Discard do
  @moduledoc """
  A sample Handler implementation of the Discard protocol

  https://en.wikipedia.org/wiki/Discard_Protocol
  """

  alias ThousandIsland.{Connection, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(conn) do
    consume(conn)
  end

  defp consume(conn) do
    Connection.recv(conn)
    consume(conn)
  end
end
