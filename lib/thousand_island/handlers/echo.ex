defmodule ThousandIsland.Handlers.Echo do
  @moduledoc """
  A sample Handler implementation of the Echo protocol

  https://en.wikipedia.org/wiki/Echo_Protocol
  """

  alias ThousandIsland.{Socket, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(conn, _opts) do
    {:ok, req} = Socket.recv(conn)
    Socket.send(conn, req)
  end
end
