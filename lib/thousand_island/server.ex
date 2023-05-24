defmodule ThousandIsland.Server do
  @moduledoc false

  use Supervisor

  @spec start_link(ThousandIsland.ServerConfig.t()) :: Supervisor.on_start()
  def start_link(%ThousandIsland.ServerConfig{} = config) do
    Supervisor.start_link(__MODULE__, config)
  end

  @spec listener_pid(Supervisor.supervisor()) :: pid() | nil
  def listener_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(nil, fn
      {:listener, listener_pid, _, _} when is_pid(listener_pid) ->
        listener_pid

      _ ->
        false
    end)
  end

  @spec acceptor_pool_supervisor_pid(Supervisor.supervisor()) :: pid() | nil
  def acceptor_pool_supervisor_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(nil, fn
      {:acceptor_pool_supervisor, acceptor_pool_sup_pid, _, _}
      when is_pid(acceptor_pool_sup_pid) ->
        acceptor_pool_sup_pid

      _ ->
        false
    end)
  end

  @impl Supervisor
  @spec init(ThousandIsland.ServerConfig.t()) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init(config) do
    children = [
      Supervisor.child_spec({ThousandIsland.Listener, config}, id: :listener),
      Supervisor.child_spec({ThousandIsland.AcceptorPoolSupervisor, {self(), config}},
        id: :acceptor_pool_supervisor
      ),
      {ThousandIsland.ShutdownListener, self()}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
