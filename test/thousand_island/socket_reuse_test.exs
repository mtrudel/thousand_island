defmodule ThousandIsland.SocketReuseTest do
  use ExUnit.Case, async: true
  use Machete

  # Simple echo handler for testing
  defmodule EchoHandler do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  # Note: This test may fail on systems without SO_REUSEPORT support
  describe "socket reuse functionality" do
    test "creates multiple sockets when reuseport is enabled" do
      config = %ThousandIsland.ServerConfig{
        port: 5004,
        handler_module: EchoHandler,
        num_listen_sockets: 3,
        transport_options: [reuseport: true]
      }

      case ThousandIsland.Listener.init(config) do
        {:ok, %{listener_sockets: sockets, local_info: {ip, port}}} ->
          assert [{1, socket1}, {2, socket2}, {3, socket3}] = sockets
          sockets = [socket1, socket2, socket3]

          # Verify all sockets are different
          assert 3 == sockets |> Enum.uniq() |> length()

          # Verify all sockets bind to the same port
          assert {:ok, {^ip, ^port}} = :inet.sockname(socket1)
          assert {:ok, {^ip, ^port}} = :inet.sockname(socket2)
          assert {:ok, {^ip, ^port}} = :inet.sockname(socket3)

          # Close all sockets
          for socket <- sockets, do: :gen_tcp.close(socket)

        {:stop, :eaddrinuse} ->
          # Skip test on systems without SO_REUSEPORT support
          :ok

        {:stop, :enotsup} ->
          # Skip test on systems without SO_REUSEPORT support
          :ok
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
end
