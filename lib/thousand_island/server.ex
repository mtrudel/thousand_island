defmodule ThousandIsland.Server do
  @moduledoc false

  use Supervisor

  def start_link(%ThousandIsland.ServerConfig{} = config) do
    Supervisor.start_link(__MODULE__, config)
  end

  def listener_pid(pid) do
    {_, listener_pid, _, _} =
      pid
      |> Supervisor.which_children()
      |> Enum.find(&Kernel.match?({:listener, _, _, _}, &1))

    listener_pid
  end

  def acceptor_pool_supervisor_pid(pid) do
    {_, acceptor_pool_supervisor_pid, _, _} =
      pid
      |> Supervisor.which_children()
      |> Enum.find(&Kernel.match?({:acceptor_pool_supervisor, _, _, _}, &1))

    acceptor_pool_supervisor_pid
  end

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
