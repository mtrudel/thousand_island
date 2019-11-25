defmodule ThousandIsland.ShutdownListener do
  @moduledoc false

  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init(server_pid) do
    Process.flag(:trap_exit, true)
    {:ok, %{server_pid: server_pid}, {:continue, :setup_listener_pid}}
  end

  def handle_continue(:setup_listener_pid, %{server_pid: server_pid}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {:noreply, %{listener_pid: listener_pid}}
  end

  def terminate(_reason, %{listener_pid: listener_pid}) do
    ThousandIsland.Listener.stop(listener_pid)
  end

  def terminate(_reason, _state), do: :ok
end
