defmodule ThousandIsland.SocketTest do
  use ExUnit.Case, async: true

  use Machete

  @eight_mb_chunks 8 * 1024 * 1024
  @large_file_size 256 * 1024 * 1024

  def gen_tcp_setup(context) do
    if context[:tmp_dir], do: maybe_create_big_file(context.tmp_dir)
    {:ok, %{client_mod: :gen_tcp, client_opts: [:binary, active: false], server_opts: []}}
  end

  def ssl_setup(context) do
    if context[:tmp_dir], do: maybe_create_big_file(context.tmp_dir)

    {:ok,
     %{
       client_mod: :ssl,
       client_opts: [
         :binary,
         active: false,
         verify: :verify_peer,
         cacertfile: Path.join(__DIR__, "../support/ca.pem")
       ],
       server_opts: [
         transport_module: ThousandIsland.Transports.SSL,
         transport_options: [
           certfile: Path.join(__DIR__, "../support/cert.pem"),
           keyfile: Path.join(__DIR__, "../support/key.pem"),
           alpn_preferred_protocols: ["foo"]
         ]
       ]
     }}
  end

  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      {:ok, data} = ThousandIsland.Socket.recv(socket, 0)
      ThousandIsland.Socket.send(socket, data)
      {:close, state}
    end
  end

  defmodule Sendfile do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      ThousandIsland.Socket.sendfile(socket, Path.join(__DIR__, "../support/sendfile"), 0, 6)
      ThousandIsland.Socket.sendfile(socket, Path.join(__DIR__, "../support/sendfile"), 1, 3)
      send(state[:test_pid], Process.info(self(), :monitored_by))
      {:close, state}
    end
  end

  defmodule LargeSendfile do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      large_file_path = Path.join(state[:tmp_dir], "large_sendfile")
      ThousandIsland.Socket.sendfile(socket, large_file_path, 0, 0)
      send(state[:test_pid], Process.info(self(), :monitored_by))
      {:close, state}
    end
  end

  defmodule Closer do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(_socket, state) do
      {:close, state}
    end
  end

  defmodule Info do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      {:ok, peer_info} = ThousandIsland.Socket.peername(socket)
      {:ok, local_info} = ThousandIsland.Socket.sockname(socket)
      negotiated_protocol = ThousandIsland.Socket.negotiated_protocol(socket)
      connection_information = ThousandIsland.Socket.connection_information(socket)

      ThousandIsland.Socket.send(
        socket,
        "#{inspect([local_info, peer_info, negotiated_protocol, connection_information])}"
      )

      {:close, state}
    end
  end

  defmodule Error do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_error(error, _socket, state) do
      send(state[:test_pid], {:handle_error, error})
      :ok
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

  [:gen_tcp_setup, :ssl_setup]
  |> Enum.each(fn setup_fn ->
    describe "common behaviour using #{setup_fn}" do
      setup setup_fn

      test "should send and receive", context do
        {:ok, port} = start_handler(Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)

        assert context.client_mod.send(client, "HELLO") == :ok
        assert context.client_mod.recv(client, 0) == {:ok, "HELLO"}
      end

      test "it should close connections", context do
        {:ok, port} = start_handler(Closer, context.server_opts)
        {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)

        assert context.client_mod.recv(client, 0) == {:error, :closed}
      end

      test "it should emit telemetry events as expected", context do
        TelemetryHelpers.attach_all_events(Echo)

        {:ok, port} = start_handler(Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)

        :ok = context.client_mod.send(client, "HELLO")
        {:ok, "HELLO"} = context.client_mod.recv(client, 0)
        context.client_mod.close(client)

        assert_receive {:telemetry, [:thousand_island, :connection, :recv], measurements,
                        metadata},
                       500

        assert measurements ~> %{data: "HELLO"}
        assert metadata ~> %{handler: Echo, telemetry_span_context: reference()}

        assert_receive {:telemetry, [:thousand_island, :connection, :send], measurements,
                        metadata},
                       500

        assert measurements ~> %{data: "HELLO"}
        assert metadata ~> %{handler: Echo, telemetry_span_context: reference()}
      end

      test "it should emit exactly one connection start and one stop event", context do
        TelemetryHelpers.attach_all_events(Echo)

        {:ok, port} = start_handler(Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)

        :ok = context.client_mod.send(client, "HELLO")
        {:ok, "HELLO"} = context.client_mod.recv(client, 0)
        context.client_mod.close(client)

        # Spans must be balanced so that consumers pairing starts with stops
        # (or keeping an active-connection gauge) stay correct
        assert_receive {:telemetry, [:thousand_island, :connection, :start], _, _}, 1000
        assert_receive {:telemetry, [:thousand_island, :connection, :stop], _, _}, 1000
        refute_receive {:telemetry, [:thousand_island, :connection, :stop], _, _}, 300
        refute_received {:telemetry, [:thousand_island, :connection, :start], _, _}
      end
    end
  end)

  describe "behaviour specific to gen_tcp" do
    setup :gen_tcp_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      {:ok, resp} = context.client_mod.recv(client, 0)
      {:ok, local_port} = :inet.port(client)

      expected =
        inspect([
          {{127, 0, 0, 1}, port},
          {{127, 0, 0, 1}, local_port},
          {:error, :protocol_not_negotiated},
          {:error, :not_secure}
        ])

      assert to_string(resp) == expected

      context.client_mod.close(client)
    end

    test "it should send files", context do
      server_opts = Keyword.put(context.server_opts, :handler_options, test_pid: self())
      {:ok, port} = start_handler(Sendfile, server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      assert context.client_mod.recv(client, 9) == {:ok, "ABCDEFBCD"}
      assert_receive {:monitored_by, []}
    end

    @tag :tmp_dir
    test "it should send large files", %{tmp_dir: tmp_dir} = context do
      opts = [test_pid: self(), tmp_dir: tmp_dir]
      server_opts = Keyword.put(context.server_opts, :handler_options, opts)
      {:ok, port} = start_handler(LargeSendfile, server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      total_received = receive_all_data(context.client_mod, client, @large_file_size, "")
      assert byte_size(total_received) == @large_file_size
      assert_receive {:monitored_by, []}
    end
  end

  describe "behaviour specific to ssl" do
    setup :ssl_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Info, context.server_opts)

      {:ok, client} =
        context.client_mod.connect(~c"localhost", port,
          active: false,
          verify: :verify_peer,
          cacertfile: Path.join(__DIR__, "../support/ca.pem"),
          alpn_advertised_protocols: ["foo"]
        )

      {:ok, {_, local_port}} = context.client_mod.sockname(client)
      {:ok, resp} = context.client_mod.recv(client, 0)

      # This is a pretty bogus hack but keeps us from having to have test dependencies on JSON
      expected_prefix =
        inspect([
          {{127, 0, 0, 1}, port},
          {{127, 0, 0, 1}, local_port},
          {:ok, "foo"}
        ])
        |> String.trim_trailing("]")

      assert ^expected_prefix <> rest = to_string(resp)
      assert rest =~ ~r/protocol/

      context.client_mod.close(client)
    end

    test "it should send files", context do
      server_opts = Keyword.put(context.server_opts, :handler_options, test_pid: self())
      {:ok, port} = start_handler(Sendfile, server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      assert context.client_mod.recv(client, 9) == {:ok, "ABCDEFBCD"}
      assert_receive {:monitored_by, [_pid]}
    end

    @tag :tmp_dir
    test "it should send large files", %{tmp_dir: tmp_dir} = context do
      opts = [test_pid: self(), tmp_dir: tmp_dir]
      server_opts = Keyword.put(context.server_opts, :handler_options, opts)
      {:ok, port} = start_handler(LargeSendfile, server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      total_received = receive_all_data(context.client_mod, client, @large_file_size, "")
      assert byte_size(total_received) == @large_file_size
      assert_receive {:monitored_by, [_pid]}
    end

    @tag capture_log: true
    test "it should close stalled handshakes once handshake_timeout has elapsed", context do
      server_opts =
        [handler_options: [test_pid: self()], handshake_timeout: 250] ++ context.server_opts

      {:ok, server_pid} =
        start_supervised({ThousandIsland, [port: 0, handler_module: Error] ++ server_opts})

      {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)

      # Connect at the TCP level but never start a TLS handshake
      {:ok, client} = :gen_tcp.connect(~c"localhost", port, active: false)

      assert_receive {:handle_error, :timeout}, 1000

      # The connection process should be gone and the socket closed underneath the client
      Process.sleep(100)
      assert ThousandIsland.connection_pids(server_pid) == {:ok, []}
      assert :gen_tcp.recv(client, 0, 100) == {:error, :closed}

      :gen_tcp.close(client)
    end

    test "it should complete handshakes as normal within handshake_timeout", context do
      {:ok, port} = start_handler(Echo, [handshake_timeout: 5_000] ++ context.server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)

      assert context.client_mod.send(client, "HELLO") == :ok
      assert context.client_mod.recv(client, 0) == {:ok, "HELLO"}
    end
  end

  describe "transports which only implement handshake/1" do
    setup :gen_tcp_setup

    test "it should fall back to handshake/1 irrespective of handshake_timeout" do
      {:ok, port} = start_handler(Echo, transport_module: LegacyTransport, handshake_timeout: 250)
      {:ok, client} = :gen_tcp.connect(~c"localhost", port, [:binary, active: false])

      assert :gen_tcp.send(client, "HELLO") == :ok
      assert :gen_tcp.recv(client, 0) == {:ok, "HELLO"}
    end

    test "it should emit exactly one connection stop event when the handshake fails", context do
      TelemetryHelpers.attach_all_events(Echo)

      {:ok, port} = start_handler(Echo, context.server_opts)

      # Force a handshake failure by offering only an unsupported cipher
      {:error, _} =
        :ssl.connect(~c"localhost", port,
          active: false,
          verify: :verify_none,
          ciphers: [%{cipher: :rc4_128, key_exchange: :rsa, mac: :md5, prf: :default_prf}]
        )

      # The failed connection's span must still stop exactly once (from the
      # handler's cleanup path), not once per failure site
      assert_receive {:telemetry, [:thousand_island, :connection, :start], _, _}, 1000
      assert_receive {:telemetry, [:thousand_island, :connection, :stop], _, _}, 1000
      refute_receive {:telemetry, [:thousand_island, :connection, :stop], _, _}, 300
      refute_received {:telemetry, [:thousand_island, :connection, :start], _, _}
    end
  end

  defp start_handler(handler, server_args) do
    resolved_args = [port: 0, handler_module: handler] ++ server_args
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, port}
  end

  defp maybe_create_big_file(tmp_dir) do
    path = Path.join(tmp_dir, "large_sendfile")

    unless File.exists?(path) and File.stat!(path).size == @large_file_size do
      # Create a large file by writing 8MB chunks to avoid memory issues
      chunks_needed = div(@large_file_size, @eight_mb_chunks)
      chunk_data = :binary.copy(<<0>>, @eight_mb_chunks)
      {:ok, file} = File.open(path, [:write, :binary])
      for _i <- 1..chunks_needed, do: IO.binwrite(file, chunk_data)
      File.close(file)
    end
  end

  defp receive_all_data(_, _, total_size, acc) when total_size <= 0, do: acc

  defp receive_all_data(client_mod, client, total_size, acc) do
    case client_mod.recv(client, @eight_mb_chunks) do
      {:ok, data} ->
        receive_all_data(client_mod, client, total_size - byte_size(data), acc <> data)

      {:error, :closed} when byte_size(acc) == total_size ->
        acc

      {:error, reason} ->
        raise "Failed to receive data: #{inspect(reason)}"
    end
  end
end
