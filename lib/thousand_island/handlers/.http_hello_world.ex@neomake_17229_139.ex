defmodule ThousandIsland.Handlers.HTTPHelloWorld do
  @moduledoc """
  A sample Handler implementation of a simple HTTP Server. Intended to be the 
  simplest thing that can answer a browser request and nothing more. Not even
  remotely strictly HTTP compliant.
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
    {:ok, _req} = Socket.recv(socket)
    Socket.send(socket, "HTTP/1.0 200 OK\r\n\r\nHello, World")
  end
end
