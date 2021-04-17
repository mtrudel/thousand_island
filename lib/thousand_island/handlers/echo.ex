defmodule ThousandIsland.Handlers.Echo do
  @moduledoc """
  A sample Handler implementation of the Echo protocol

  https://en.wikipedia.org/wiki/Echo_Protocol
  """

  @behaviour ThousandIsland.Handler

  use Task

  alias ThousandIsland.{Handler, Socket}

  @impl Handler
  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    # Optional - setting this allows handlers to continue running for a period after the server starts shutdown
    Process.flag(:trap_exit, true)

    {:ok, socket} = Socket.get_socket()
    {:ok, req} = Socket.recv(socket)
    Socket.send(socket, req)
  end
end
