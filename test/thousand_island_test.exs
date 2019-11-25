defmodule ThousandIslandTest do
  use ExUnit.Case, async: true

  alias ThousandIsland.Transports.SSL
  alias ThousandIsland.Handlers.Echo

  describe "TCP transport" do
    setup do
      {:ok, server_pid} = start_supervised({ThousandIsland, port: 0, handler_module: Echo})
      {:ok, port} = ThousandIsland.local_port(server_pid)
      {:ok, %{server_pid: server_pid, port: port}}
    end

    test "should handle connections as expected", context do
      {:ok, client} = :gen_tcp.connect(:localhost, context.port, active: false)

      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, 'HELLO'}
      :gen_tcp.close(client)
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

  describe "SSL transport" do
    setup do
      {:ok, server_pid} =
        start_supervised(
          {ThousandIsland,
           port: 0,
           transport_module: SSL,
           transport_options: [
             certfile: Path.join(__DIR__, "support/cert.pem"),
             keyfile: Path.join(__DIR__, "support/key.pem")
           ],
           handler_module: Echo}
        )

      {:ok, port} = ThousandIsland.local_port(server_pid)
      {:ok, %{server_pid: server_pid, port: port}}
    end

    test "should handle connections as expected", context do
      {:ok, client} = :ssl.connect(:localhost, context.port, [active: false], :infinity)

      :ok = :ssl.send(client, "HELLO")
      assert :ssl.recv(client, 0) == {:ok, 'HELLO'}
      :ssl.close(client)
    end
  end
end
