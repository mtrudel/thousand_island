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

  def init(config) do
    children = [
      Supervisor.child_spec({ThousandIsland.Listener, config}, id: :listener),
      {ThousandIsland.AcceptorPoolSupervisor, {self(), config}},
      {ThousandIsland.ShutdownListener, self()}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
