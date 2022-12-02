defmodule ThousandIsland.Acceptor do
  @moduledoc false

  use GenServer, restart: :transient

  def start_link(arg), do: GenServer.start_link(__MODULE__, arg)

  def init(arg) do
    {:ok, nil, {:continue, arg}}
  end

  def handle_continue(
        {server_pid, parent_pid, %ThousandIsland.ServerConfig{} = server_config},
        nil
      ) do
    listener_socket =
      server_pid
      |> ThousandIsland.Server.listener_pid()
      |> ThousandIsland.Listener.acceptor_info()

    state = %{
      sup_pid: ThousandIsland.AcceptorSupervisor.connection_sup_pid(parent_pid),
      child_spec: {server_config.handler_module, {self(), listener_socket, server_config}}
    }

    for _ <- 1..10, do: GenServer.cast(self(), :new)

    {:noreply, state}
  end

  def handle_cast(:new, state) do
    DynamicSupervisor.start_child(state.sup_pid, state.child_spec)
    {:noreply, state}
  end
end
