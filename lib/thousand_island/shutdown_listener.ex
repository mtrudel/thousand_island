defmodule ThousandIsland.ShutdownListener do
  @moduledoc false

  # Used as part of the `ThousandIsland.Server` supervision tree to facilitate
  # stopping the server's listener process early in the shutdown process, in order
  # to allow existing connections to drain without accepting new ones

  use GenServer

  @type state :: pid() | nil

  @doc false
  @spec start_link({pid(), any()}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link({server_pid, key}) do
    GenServer.start_link(__MODULE__, {server_pid, key})
  end

  @doc false
  @impl GenServer
  @spec init({pid(), any()}) ::
          {:ok, state, {:continue, {:setup_listener_pid, server_pid :: pid()}}}
  def init({server_pid, key}) do
    Process.flag(:trap_exit, true)
    ThousandIsland.ProcessLabel.set(:shutdown_listener, key)
    {:ok, nil, {:continue, {:setup_listener_pid, server_pid}}}
  end

  @doc false
  @impl GenServer
  @spec handle_continue({:setup_listener_pid, pid()}, state) :: {:noreply, state}
  def handle_continue({:setup_listener_pid, server_pid}, nil) do
    {:noreply, ThousandIsland.Server.listener_pid(server_pid)}
  end

  @doc false
  @impl GenServer
  @spec terminate(reason, state) :: :ok
        when reason: :normal | :shutdown | {:shutdown, term} | term
  def terminate(_reason, listener_pid) when is_pid(listener_pid) do
    ThousandIsland.Listener.stop(listener_pid)
  end

  def terminate(_reason, _state), do: :ok
end
