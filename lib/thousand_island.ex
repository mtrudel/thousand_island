defmodule ThousandIsland do
  def local_port(pid) do
    {:ok, listener_pid} =
      pid
      |> ThousandIsland.Server.listener_pid()
      |> ThousandIsland.Listener.listener_socket()

    :inet.port(listener_pid)
  end
end
