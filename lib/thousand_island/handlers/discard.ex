defmodule ThousandIsland.Handlers.Discard do
  @moduledoc """
  A sample Handler implementation of the Discard protocol

  https://en.wikipedia.org/wiki/Discard_Protocol
  """

  alias ThousandIsland.{Socket, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(socket, _opts) do
    consume(socket)
  end

  defp consume(socket) do
    if match?({:ok, _data}, Socket.recv(socket)), do: consume(socket)
  end
end
