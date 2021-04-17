defmodule ThousandIsland.Handlers.Discard do
  @moduledoc """
  A sample Handler implementation of the Discard protocol

  https://en.wikipedia.org/wiki/Discard_Protocol
  """

  @behaviour ThousandIsland.Handler

  use Task

  alias ThousandIsland.{Handler, Socket}

  @impl Handler
  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    {:ok, socket} = Socket.get_socket()

    consume(socket)
  end

  defp consume(socket) do
    if match?({:ok, _data}, Socket.recv(socket)), do: consume(socket)
  end
end
