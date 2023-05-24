defmodule ThousandIsland.AcceptorSupervisor do
  @moduledoc false

  use Supervisor

  @spec start_link({server_pid :: pid, ThousandIsland.ServerConfig.t()}) ::
          :ignore | {:ok, pid} | {:error, {:already_started, pid} | {:shutdown, term} | term}
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @spec connection_sup_pid(Supervisor.supervisor()) :: pid() | nil
  def connection_sup_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.reduce_while(nil, fn
      {:connection_sup, connection_sup_pid, _, _}, _acc when is_pid(connection_sup_pid) ->
        {:halt, connection_sup_pid}

      _, acc ->
        {:cont, acc}
    end)
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
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
