defmodule ThousandIsland.Handlers.Messenger do
  @moduledoc """
  A sample Handler implementation that allows for simultaneous bidirectional sending
  of messages to demonstrate that the Handler process is just a GenServer under the
  hood
  """

  use ThousandIsland.Handler

  def send_message(pid, msg) do
    GenServer.cast(pid, {:send, msg})
  end

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    %{address: remote_address} = ThousandIsland.Socket.peer_info(socket)

    IO.puts("#{inspect(self())} received connection from #{remote_address}")

    {:ok, :continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(msg, _socket, state) do
    IO.puts("Received #{msg}")
    {:ok, :continue, state}
  end

  @impl GenServer
  def handle_cast({:send, msg}, {socket, state}) do
    ThousandIsland.Socket.send(socket, msg)
    {:noreply, {socket, state}}
  end
end
