defmodule ThousandIsland.Handlers.Echo do
  @moduledoc """
  A sample Handler implementation of the Echo protocol

  https://en.wikipedia.org/wiki/Echo_Protocol
  """

  alias ThousandIsland.{Handler, Socket}

  @behaviour Handler

  @impl Handler
  def handle_connection(socket, _opts) do
    {:ok, req} = Socket.recv(socket)
    Socket.send(socket, req)
  end
end
