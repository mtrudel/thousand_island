defmodule ThousandIsland.AcceptorSupervisor do
  @moduledoc false

  use Supervisor

  @spec start_link({server_pid :: pid, ThousandIsland.ServerConfig.t()}) :: Supervisor.on_start()
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec connection_sup_pid(Supervisor.supervisor()) :: pid() | nil
  def connection_sup_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {:connection_sup, connection_sup_pid, _, _} when is_pid(connection_sup_pid) ->
        connection_sup_pid

      _ ->
        false
    end)
  end

  @spec suspend(Supervisor.supervisor()) :: :ok | :error
  def suspend(pid) do
    case Supervisor.terminate_child(pid, :acceptor) do
      :ok -> :ok
      {:error, :not_found} -> :error
    end
  end

  @spec resume(Supervisor.supervisor()) :: :ok | :error
  def resume(pid) do
    case Supervisor.restart_child(pid, :acceptor) do
      {:ok, _child} -> :ok
      {:error, reason} when reason in [:running, :restarting] -> :ok
      {:error, _reason} -> :error
    end
  end

  @impl Supervisor
  @spec init({server_pid :: pid, ThousandIsland.ServerConfig.t()}) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init({server_pid, %ThousandIsland.ServerConfig{} = config}) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, max_children: config.num_connections}
      |> Supervisor.child_spec(id: :connection_sup),
      {ThousandIsland.Acceptor, {server_pid, self(), config}}
      |> Supervisor.child_spec(id: :acceptor)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
