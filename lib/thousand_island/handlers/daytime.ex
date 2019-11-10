defmodule ThousandIsland.Handlers.Daytime do
  @moduledoc """
  A sample Handler implementation of the Daytime protocol

  https://en.wikipedia.org/wiki/Daytime_Protocol
  """

  alias ThousandIsland.{Connection, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(conn) do
    time = DateTime.utc_now() |> to_string()
    Connection.send(conn, time)
  end
end
