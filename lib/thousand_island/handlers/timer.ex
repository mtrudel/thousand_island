defmodule ThousandIsland.Handlers.Timer do
  @moduledoc """
  A sample Handler implementation which sends the time out every second, until
  the remote end sends any data.
  """

  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(_socket, state) do
    Process.send_after(self(), :time, 1000)
    {:ok, :continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(_data, _socket, state) do
    {:ok, :close, state}
  end

  def handle_info(:time, {socket, _} = state) do
    time = DateTime.utc_now() |> to_string()
    ThousandIsland.Socket.send(socket, time <> "\n")
    Process.send_after(self(), :time, 1000)
    {:noreply, state}
  end
end
