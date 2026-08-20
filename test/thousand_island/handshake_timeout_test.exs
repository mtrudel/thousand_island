defmodule ThousandIsland.HandshakeTimeoutTest do
  use ExUnit.Case, async: true

  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  defmodule Error do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_error(error, _socket, state) do
      # Send error to test process
      case :proplists.get_value(:test_pid, state) do
        pid when is_pid(pid) ->
          send(pid, error)
          :ok

        _ ->
          raise "missing :test_pid for Error handler"
      end
    end
  end

  defmodule LegacyTransport do
    # A transport which implements only the original handshake/1 callback, as any third-party
    # transport written before the optional handshake/2 callback existed would. Everything else
    # delegates to the TCP transport
    @behaviour ThousandIsland.Transport

    @impl ThousandIsland.Transport
    defdelegate listen(port, options), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate accept(listener_socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    def handshake(socket), do: {:ok, socket}

    @impl ThousandIsland.Transport
    defdelegate upgrade(socket, opts), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate controlling_process(socket, pid), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate recv(socket, length, timeout), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate send(socket, data), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate sendfile(socket, filename, offset, length), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate getopts(socket, options), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate setopts(socket, options), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate shutdown(socket, way), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate close(socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate sockname(socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate peername(socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate peercert(socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate secure?(), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate getstat(socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate negotiated_protocol(socket), to: ThousandIsland.Transports.TCP

    @impl ThousandIsland.Transport
    defdelegate connection_information(socket), to: ThousandIsland.Transports.TCP
  end

  describe "configuration" do
    test "handshake_timeout defaults to 5000 ms and accepts :infinity" do
      config = ThousandIsland.ServerConfig.new(handler_module: Echo)
      assert config.handshake_timeout == 5_000

      config = ThousandIsland.ServerConfig.new(handler_module: Echo, handshake_timeout: :infinity)
      assert config.handshake_timeout == :infinity
    end
  end

  describe "TLS handshakes" do
    @tag capture_log: true
    test "a stalled handshake is actively closed once handshake_timeout elapses" do
      {:ok, server_pid, port} =
        start_handler(Error,
          handler_options: [test_pid: self()],
          handshake_timeout: 250,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            certfile: Path.join(__DIR__, "../support/cert.pem"),
            keyfile: Path.join(__DIR__, "../support/key.pem")
          ]
        )

      # Connect at the TCP level but never start a TLS handshake
      {:ok, client} = :gen_tcp.connect(~c"localhost", port, active: false)

      assert_receive :timeout, 1000

      # The connection process should be gone and the socket closed underneath the client
      Process.sleep(100)
      assert {:ok, []} = ThousandIsland.connection_pids(server_pid)
      assert :gen_tcp.recv(client, 0, 100) == {:error, :closed}

      :gen_tcp.close(client)
    end

    test "well-behaved clients handshake and communicate normally under the default timeout" do
      {:ok, _server_pid, port} =
        start_handler(Echo,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            certfile: Path.join(__DIR__, "../support/cert.pem"),
            keyfile: Path.join(__DIR__, "../support/key.pem")
          ]
        )

      {:ok, client} =
        :ssl.connect(~c"localhost", port,
          active: false,
          verify: :verify_peer,
          cacertfile: Path.join(__DIR__, "../support/ca.pem")
        )

      :ok = :ssl.send(client, "HELLO")
      assert :ssl.recv(client, 5, 1000) == {:ok, ~c"HELLO"}

      :ssl.close(client)
    end
  end

  describe "backwards compatibility" do
    test "transports which implement only handshake/1 continue to work" do
      {:ok, _server_pid, port} =
        start_handler(Echo, transport_module: LegacyTransport, handshake_timeout: 250)

      {:ok, client} = :gen_tcp.connect(~c"localhost", port, active: false)
      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0, 1000) == {:ok, ~c"HELLO"}

      :gen_tcp.close(client)
    end
  end

  defp start_handler(handler, opts) do
    resolved_args = opts |> Keyword.put_new(:port, 0) |> Keyword.put(:handler_module, handler)
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, server_pid, port}
  end
end
