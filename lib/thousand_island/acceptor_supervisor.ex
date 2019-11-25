defmodule ThousandIsland.AcceptorSupervisor do
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
      Supervisor.child_spec({DynamicSupervisor, strategy: :one_for_one}, id: :connection_sup),
      {ThousandIsland.Acceptor, {server_pid, self(), config}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
