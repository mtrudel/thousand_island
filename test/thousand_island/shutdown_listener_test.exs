defmodule ThousandIsland.ShutdownListenerTest do
  use ExUnit.Case, async: true

  test "shuts down cleanly when the server has no listener child" do
    Process.flag(:trap_exit, true)
    {:ok, supervisor_pid} = Supervisor.start_link([], strategy: :one_for_one)

    {:ok, pid} = ThousandIsland.ShutdownListener.start_link({supervisor_pid, "test"})

    :ok = GenServer.stop(pid, :shutdown)
    assert_receive {:EXIT, ^pid, :shutdown}
  end
end
