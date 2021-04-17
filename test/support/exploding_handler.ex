defmodule ThousandIsland.Handlers.Exploding do
  @moduledoc false

  @behaviour ThousandIsland.Handler

  use Task

  alias ThousandIsland.{Handler, Socket}

  @impl Handler
  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    {:ok, _socket} = Socket.get_socket()
    raise "boom"
  end
end
