defmodule ThousandIsland.Handlers.Daytime do
  @moduledoc """
  A sample Handler implementation of the Daytime protocol

  https://en.wikipedia.org/wiki/Daytime_Protocol
  """

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    time = DateTime.utc_now() |> to_string()
    ThousandIsland.Socket.send(socket, time)
    {:ok, :close, state}
  end
end
