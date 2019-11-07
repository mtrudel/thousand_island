defmodule ThousandIsland.Server do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def listener_pid(pid) do
    {_, listener_pid, _, _} =
      pid
      |> Supervisor.which_children()
      |> Enum.find(&Kernel.match?({:listener, _, _, _}, &1))

    listener_pid
  end

  @impl true
  def init(opts) do
    children = [
      Supervisor.child_spec({ThousandIsland.Listener, opts}, id: :listener),
      {ThousandIsland.AcceptorSupervisor, {self(), opts}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
