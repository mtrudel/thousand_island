defmodule ThousandIsland.Acceptor do
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

  def init({server_pid, opts}) do
    children = [
      Supervisor.child_spec({ThousandIsland.ConnectionSupervisor, opts}, id: :connection_sup),
      {ThousandIsland.AcceptorWorker, {server_pid, self(), opts}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
