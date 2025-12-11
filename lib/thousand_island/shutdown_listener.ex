defmodule ThousandIsland.ShutdownListener do
  @moduledoc false

  # Used as part of the `ThousandIsland.Server` supervision tree to facilitate
  # stopping the server's listener process early in the shutdown process, in order
  # to allow existing connections to drain without accepting new ones

  use GenServer

  @type state :: %{
          optional(:server_pid) => pid(),
          optional(:listener_pid) => pid() | nil
        }

  @doc false
  @spec start_link(pid()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(server_pid) do
    GenServer.start_link(__MODULE__, server_pid)
  end

  @doc false
  @impl GenServer
  @spec init(pid()) :: {:ok, state, {:continue, :setup_listener_pid}}
  def init(server_pid) do
    Process.flag(:trap_exit, true)
    {:ok, %{server_pid: server_pid}, {:continue, :setup_listener_pid}}
  end

  @doc false
  @impl GenServer
  @spec handle_continue(:setup_listener_pid, state) :: {:noreply, state}
  def handle_continue(:setup_listener_pid, %{server_pid: server_pid}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {:noreply, %{listener_pid: listener_pid}}
  end

  @doc false
  @impl GenServer
  @spec terminate(reason, state) :: :ok
        when reason: :normal | :shutdown | {:shutdown, term} | term
  def terminate(_reason, %{listener_pid: listener_pid}) do
    ThousandIsland.Listener.stop(listener_pid)
  end

  def terminate(_reason, _state), do: :ok
end
