defmodule ThousandIsland.AcceptorSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  def connection_sup_pid(pid) do
    {_, connection_sup_pid, _, _} =
      pid
      |> Supervisor.which_children()
      |> Enum.find(&Kernel.match?({:connection_sup, _, _, _}, &1))

    connection_sup_pid
  end

  def init({server_pid, %ThousandIsland.ServerConfig{} = config}) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, max_children: config.num_connections}
      |> Supervisor.child_spec(id: :connection_sup),
      {ThousandIsland.Acceptor, {server_pid, self(), config}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
