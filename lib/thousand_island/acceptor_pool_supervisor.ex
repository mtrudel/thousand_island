defmodule ThousandIsland.AcceptorPoolSupervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  def init({server_pid, opts}) do
    num_acceptors = Keyword.get(opts, :num_acceptors, 10)
    base_spec = {ThousandIsland.AcceptorSupervisor, {server_pid, opts}}

    1..num_acceptors
    |> Enum.map(&Supervisor.child_spec(base_spec, id: "acceptor-#{&1}"))
    |> Supervisor.init(strategy: :one_for_one)
  end
end
