defmodule ThousandIsland.Listener do
  use GenServer

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def listener_state(pid) do
    GenServer.call(pid, :listener_state)
  end

  def init(opts) do
    transport_module = ThousandIsland.Transport.transport_module(opts)
    {:ok, listener_state} = transport_module.listen(opts)
    {:ok, %{listener_state: listener_state}}
  end

  def handle_call(:listener_state, _from, %{listener_state: listener_state} = state) do
    {:reply, {:ok, listener_state}, state}
  end
end
