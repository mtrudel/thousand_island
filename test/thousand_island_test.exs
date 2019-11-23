defmodule ThousandIslandTest do
  use ExUnit.Case, async: true

  alias ThousandIsland.Transports.SSL
  alias ThousandIsland.Handlers.Echo

  describe "TCP transport" do
    setup do
      {:ok, server_pid} = start_supervised({ThousandIsland, port: 0, handler_module: Echo})
      {:ok, port} = ThousandIsland.local_port(server_pid)
      {:ok, %{port: port}}
    end

    test "should handle connections as expected", %{port: port} do
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      try do
        :ok = :gen_tcp.send(client, "HELLO")
        assert :gen_tcp.recv(client, 0) == {:ok, 'HELLO'}
      after
        :gen_tcp.close(client)
      end
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
      {:ok, %{port: port}}
    end

    test "should handle connections as expected", %{port: port} do
      {:ok, client} = :ssl.connect(:localhost, port, [active: false], :infinity)

      try do
        :ok = :ssl.send(client, "HELLO")
        assert :ssl.recv(client, 0) == {:ok, 'HELLO'}
      after
        :ssl.close(client)
      end
    end
  end
end
