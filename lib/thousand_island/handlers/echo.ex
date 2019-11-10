defmodule ThousandIsland.Handlers.Echo do
  @moduledoc """
  A sample Handler implementation of the Echo protocol

  https://en.wikipedia.org/wiki/Echo_Protocol
  """

  alias ThousandIsland.{Connection, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(conn) do
    {:ok, req} = Connection.recv(conn)
    Connection.send(conn, req)
  end
end
