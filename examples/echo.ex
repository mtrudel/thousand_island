defmodule Echo do
  @moduledoc """
  A sample Handler implementation of the Echo protocol

  https://en.wikipedia.org/wiki/Echo_Protocol
  """

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    ThousandIsland.Socket.send(socket, data)
    {:continue, state}
  end
end
