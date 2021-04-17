defmodule ThousandIsland.Handlers.EchoGenServer do
  @moduledoc """
  A sample Handler implementation of the Echo protocol using a GenServer process

  https://en.wikipedia.org/wiki/Echo_Protocol
  """

  @behaviour ThousandIsland.Handler

  use GenServer, restart: :temporary

  alias ThousandIsland.{Handler, Socket}

  @impl Handler
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  @impl GenServer
  def init(_arg) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_info({:thousand_island_ready, socket}, state) do
    {:ok, socket} = Socket.handshake(socket)
    {:ok, req} = Socket.recv(socket)
    Socket.send(socket, req)

    {:stop, :shutdown, state}
  end
end
