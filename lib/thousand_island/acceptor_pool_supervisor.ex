defmodule ThousandIsland.AcceptorPoolSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  def acceptor_supervisor_pids(pid) do
    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {_, acceptor_pid, _, _} -> acceptor_pid end)
    |> Enum.filter(&Kernel.is_pid/1)
  end

  def init({server_pid, %ThousandIsland.ServerConfig{num_acceptors: num_acceptors} = config}) do
    base_spec = {ThousandIsland.AcceptorSupervisor, {server_pid, config}}

    1..num_acceptors
    |> Enum.map(&Supervisor.child_spec(base_spec, id: "acceptor-#{&1}"))
    |> Supervisor.init(strategy: :one_for_one)
  end
end
