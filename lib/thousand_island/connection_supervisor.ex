defmodule ThousandIsland.ConnectionSupervisor do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg)
  end

  def start_connection(pid, args) do
    DynamicSupervisor.start_child(pid, {ThousandIsland.Connection, args})
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
