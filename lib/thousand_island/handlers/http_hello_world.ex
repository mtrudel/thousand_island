defmodule ThousandIsland.Handlers.HTTPHelloWorld do
  @moduledoc """
  A sample Handler implementation of a simple HTTP Server. Intended to be the 
  simplest thing that can answer a browser request and nothing more. Not even
  remotely strictly HTTP compliant.
  """

  alias ThousandIsland.{Handler, Socket}

  @behaviour Handler

  @impl Handler
  def handle_connection(socket, _opts) do
    {:ok, _req} = Socket.recv(socket)
    Socket.send(socket, "HTTP/1.0 200 OK\r\n\r\nHello, World")
  end
end
