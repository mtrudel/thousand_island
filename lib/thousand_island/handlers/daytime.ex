defmodule ThousandIsland.Handlers.Daytime do
  @moduledoc """
  A sample Handler implementation of the Daytime protocol

  https://en.wikipedia.org/wiki/Daytime_Protocol
  """

  alias ThousandIsland.{Socket, Handler}

  @behaviour Handler

  @impl Handler
  def handle_connection(socket, _opts) do
    time = DateTime.utc_now() |> to_string()
    Socket.send(socket, time)
  end
end
