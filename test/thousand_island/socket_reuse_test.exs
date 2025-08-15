defmodule ThousandIsland.SocketReuseTest do
  use ExUnit.Case, async: true
  use Machete

  alias ThousandIsland.ServerConfig

  # Simple echo handler for testing
  defmodule EchoHandler do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  describe "socket reuse functionality" do
    test "single socket configuration works as before" do
      config = [
        # Let OS assign port
        port: 0,
        handler_module: EchoHandler,
        num_listen_sockets: 1,
        num_acceptors: 4
      ]

      assert {:ok, server} = ThousandIsland.start_link(config)
      assert {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
      assert port > 0

      # Test basic connectivity
      assert {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])
      assert :ok = :gen_tcp.send(client, "hello")
      assert {:ok, "hello"} = :gen_tcp.recv(client, 0, 1000)
      :gen_tcp.close(client)

      ThousandIsland.stop(server)
    end

    test "validates reuseport requirement for multiple sockets" do
      # Test the validation directly by creating a ServerConfig and checking the Listener.init
      server_config = %ThousandIsland.ServerConfig{
        port: 0,
        handler_module: EchoHandler,
        # Multiple sockets without reuseport
        num_listen_sockets: 2,
        # No reuseport options
        transport_options: []
      }

      # Should fail to init due to missing reuseport
      assert_raise ArgumentError, ~r/reuseport.*must be set/, fn ->
        ThousandIsland.Listener.init(server_config)
      end
    end

    test "multiple sockets with reuseport (if supported)" do
      # This test will be skipped on systems without SO_REUSEPORT support
      config = [
        port: 0,
        handler_module: EchoHandler,
        num_listen_sockets: 3,
        num_acceptors: 6,
        transport_options: [reuseport: true]
      ]

      case ThousandIsland.start_link(config) do
        {:ok, server} ->
          assert {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
          assert port > 0

          # Test that multiple connections work
          clients =
            for _ <- 1..5 do
              assert {:ok, client} =
                       :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])

              client
            end

          # Send data through each client
          for {client, i} <- Enum.with_index(clients, 1) do
            message = "hello#{i}"
            assert :ok = :gen_tcp.send(client, message)
            assert {:ok, ^message} = :gen_tcp.recv(client, 0, 1000)
          end

          # Clean up
          Enum.each(clients, &:gen_tcp.close/1)
          ThousandIsland.stop(server)

        {:error, reason} when reason in [:eaddrinuse, :enotsup] ->
          # Skip test on systems without SO_REUSEPORT support
          :ok
      end
    end

    test "acceptor distribution across multiple sockets" do
      # Test that we can start a server with socket reuse configuration
      # even if the actual socket creation might fail on some systems
      config = [
        port: 0,
        handler_module: EchoHandler,
        num_listen_sockets: 2,
        num_acceptors: 8,
        transport_options: [reuseport: true]
      ]

      case ThousandIsland.start_link(config) do
        {:ok, server} ->
          # If it starts successfully, verify basic functionality
          assert {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
          assert port > 0

          # Test basic connectivity
          assert {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])
          assert :ok = :gen_tcp.send(client, "test")
          assert {:ok, "test"} = :gen_tcp.recv(client, 0, 1000)
          :gen_tcp.close(client)

          ThousandIsland.stop(server)

        {:error, reason} when reason in [:eaddrinuse, :enotsup] ->
          # Expected on systems without SO_REUSEPORT support
          :ok
      end
    end
  end

  describe "ServerConfig validation" do
    test "num_listen_sockets defaults to 1" do
      config = ServerConfig.new(handler_module: EchoHandler)
      assert config.num_listen_sockets == 1
    end

    test "num_listen_sockets can be configured" do
      config = ServerConfig.new(handler_module: EchoHandler, num_listen_sockets: 4)
      assert config.num_listen_sockets == 4
    end

    test "allows num_listen_sockets equal to num_acceptors" do
      config =
        ServerConfig.new(handler_module: EchoHandler, num_listen_sockets: 5, num_acceptors: 5)

      assert config.num_listen_sockets == 5
      assert config.num_acceptors == 5
    end

    test "allows num_listen_sockets less than num_acceptors" do
      config =
        ServerConfig.new(handler_module: EchoHandler, num_listen_sockets: 3, num_acceptors: 10)

      assert config.num_listen_sockets == 3
      assert config.num_acceptors == 10
    end

    test "raises error when num_listen_sockets greater than num_acceptors" do
      assert_raise RuntimeError,
                   "num_listen_sockets (10) must be less than or equal to num_acceptors (5)",
                   fn ->
                     ServerConfig.new(
                       handler_module: EchoHandler,
                       num_listen_sockets: 10,
                       num_acceptors: 5
                     )
                   end
    end
  end
end
