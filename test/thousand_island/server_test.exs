defmodule ThousandIsland.ServerTest do
  use ExUnit.Case

  describe "tests with an echo handler" do
    setup do
      {:ok, server_pid} =
        start_supervised(
          {ThousandIsland, port: 0, handler_module: ThousandIsland.Handlers.SyncEcho}
        )

      {:ok, port} = ThousandIsland.local_port(server_pid)
      {:ok, %{server_pid: server_pid, port: port}}
    end

    test "should handle multiple connections as expected", context do
      {:ok, client} = :gen_tcp.connect(:localhost, context.port, active: false)
      {:ok, other_client} = :gen_tcp.connect(:localhost, context.port, active: false)

      :ok = :gen_tcp.send(client, "HELLO")
      :ok = :gen_tcp.send(other_client, "BONJOUR")

      # Invert the order to ensure we handle concurrently
      assert :gen_tcp.recv(other_client, 0) == {:ok, 'BONJOUR'}
      assert :gen_tcp.recv(client, 0) == {:ok, 'HELLO'}

      :gen_tcp.close(client)
      :gen_tcp.close(other_client)
    end

    test "it should stop accepting connections but allow existing ones to complete", context do
      {:ok, client} = :gen_tcp.connect(:localhost, context.port, active: false)

      # Make sure the socket has transitioned ownership to the connection process
      Process.sleep(100)
      task = Task.async(fn -> ThousandIsland.stop(context.server_pid) end)
      # Make sure that the stop has had a chance to shutdown the acceptors
      Process.sleep(100)

      assert :gen_tcp.connect(:localhost, context.port, [active: false], 100) ==
               {:error, :econnrefused}

      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, 'HELLO'}
      :gen_tcp.close(client)

      Task.await(task)
    end
  end
end
