defmodule ThousandIsland.Server do
  @moduledoc false

  use Supervisor

  @spec start_link(ThousandIsland.ServerConfig.t()) :: Supervisor.on_start()
  def start_link(%ThousandIsland.ServerConfig{} = config) do
    Supervisor.start_link(__MODULE__, config, config.supervisor_options)
  end

  @spec listener_pid(Supervisor.supervisor()) :: pid() | nil
  def listener_pid(supervisor), do: child_pid(supervisor, :listener)

  @spec acceptor_pool_supervisor_pid(Supervisor.supervisor()) :: pid() | nil
  def acceptor_pool_supervisor_pid(supervisor),
    do: child_pid(supervisor, :acceptor_pool_supervisor)

  defp child_pid(supervisor, child_id) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {^child_id, child_pid, _, _} when is_pid(child_pid) ->
        child_pid

      _ ->
        nil
    end)
  end

  @spec suspend(Supervisor.supervisor()) :: :ok | :error
  def suspend(pid) do
    with pool_sup_pid when is_pid(pool_sup_pid) <- acceptor_pool_supervisor_pid(pid),
         :ok <- ThousandIsland.AcceptorPoolSupervisor.suspend(pool_sup_pid),
         :ok <- Supervisor.terminate_child(pid, :shutdown_listener),
         :ok <- Supervisor.terminate_child(pid, :listener) do
      :ok
    else
      _ -> :error
    end
  end

  @spec resume(Supervisor.supervisor()) :: :ok | :error
  def resume(pid) do
    with :ok <- wrap_restart_child(pid, :listener),
         :ok <- wrap_restart_child(pid, :shutdown_listener),
         pool_sup_pid when is_pid(pool_sup_pid) <- acceptor_pool_supervisor_pid(pid),
         :ok <- ThousandIsland.AcceptorPoolSupervisor.resume(pool_sup_pid) do
      :ok
    else
      _ -> :error
    end
  end

  defp wrap_restart_child(pid, id) do
    case Supervisor.restart_child(pid, id) do
      {:ok, _child} -> :ok
      {:error, reason} when reason in [:running, :restarting] -> :ok
      {:error, _reason} -> :error
    end
  end

  @impl Supervisor
  @spec init(ThousandIsland.ServerConfig.t()) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init(config) do
    ThousandIsland.ProcessLabel.set(:server, config)

    children = [
      {ThousandIsland.Listener, config} |> Supervisor.child_spec(id: :listener),
      {ThousandIsland.AcceptorPoolSupervisor, {self(), config}}
      |> Supervisor.child_spec(id: :acceptor_pool_supervisor),
      {ThousandIsland.ShutdownListener, {self(), config}}
      |> Supervisor.child_spec(id: :shutdown_listener)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
