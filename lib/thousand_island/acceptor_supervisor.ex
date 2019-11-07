defmodule ThousandIsland.AcceptorSupervisor do
  use Supervisor

  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  @impl true
  def init({server_pid, opts}) do
    num_acceptors = Keyword.get(opts, :num_acceptors, 10)
    base_spec = {ThousandIsland.Acceptor, {server_pid, opts}}

    Logger.info("Starting #{num_acceptors} acceptors")

    1..num_acceptors
    |> Enum.map(&Supervisor.child_spec(base_spec, id: "acceptor-#{&1}"))
    |> Supervisor.init(strategy: :one_for_one)
  end
end
