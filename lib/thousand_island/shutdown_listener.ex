defmodule ThousandIsland.ShutdownListener do
  @moduledoc false

  # Used as part of the `ThousandIsland.Server` supervision tree to facilitate
  # stopping the server's listener process early in the shutdown process, in order
  # to allow existing connections to drain without accepting new ones

  use GenServer

  @doc false
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  @doc false
  def init(server_pid) do
    Process.flag(:trap_exit, true)
    {:ok, %{server_pid: server_pid}, {:continue, :setup_listener_pid}}
  end

  @doc false
  def handle_continue(:setup_listener_pid, %{server_pid: server_pid}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {:noreply, %{listener_pid: listener_pid}}
  end

  @doc false
  def terminate(_reason, %{listener_pid: listener_pid}) do
    ThousandIsland.Listener.stop(listener_pid)
  end

  def terminate(_reason, _state), do: :ok
end
