defmodule ThousandIsland.ServerTest do
  # False due to telemetry raciness
  use ExUnit.Case, async: false

  use Machete

  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      {:ok, data} = ThousandIsland.Socket.recv(socket, 0)
      ThousandIsland.Socket.send(socket, data)
      {:close, state}
    end
  end

  defmodule LongEcho do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  defmodule Goodbye do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_shutdown(socket, state) do
      ThousandIsland.Socket.send(socket, "GOODBYE")
      {:close, state}
    end
  end

  defmodule ReadOpt do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      opts = [String.to_atom(data)]
      ThousandIsland.Socket.send(socket, inspect(ThousandIsland.Socket.getopts(socket, opts)))
      {:close, state}
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

  defmodule Whoami do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      ThousandIsland.Socket.send(socket, :erlang.pid_to_list(self()))
      {:continue, state}
    end
  end

  test "should handle multiple connections as expected" do
    {:ok, _, port} = start_handler(Echo)
    {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
    {:ok, other_client} = :gen_tcp.connect(:localhost, port, active: false)

    :ok = :gen_tcp.send(client, "HELLO")
    :ok = :gen_tcp.send(other_client, "BONJOUR")

    # Invert the order to ensure we handle concurrently
    assert :gen_tcp.recv(other_client, 0) == {:ok, ~c"BONJOUR"}
    assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

    :gen_tcp.close(client)
    :gen_tcp.close(other_client)
  end

  describe "num_connections handling" do
    test "should properly handle too many connections by queueing" do
      {:ok, _, port} = start_handler(LongEcho, num_acceptors: 1, num_connections: 1)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, other_client} = :gen_tcp.connect(:localhost, port, active: false)

      :ok = :gen_tcp.send(client, "HELLO")
      :ok = :gen_tcp.send(other_client, "BONJOUR")

      # Give things enough time to send if they were going to
      Process.sleep(100)

      # Ensure that we haven't received anything on the second connection yet
      assert :gen_tcp.recv(other_client, 0, 10) == {:error, :timeout}
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

      # Close our first connection to make room for the second to be accepted
      :gen_tcp.close(client)

      # Give things enough time to send if they were going to
      Process.sleep(100)

      # Ensure that the second connection unblocked
      assert :gen_tcp.recv(other_client, 0) == {:ok, ~c"BONJOUR"}
      :gen_tcp.close(other_client)
    end

    test "should properly handle too many connections if none close in time" do
      {:ok, _, port} =
        start_handler(LongEcho,
          num_acceptors: 1,
          num_connections: 1,
          max_connections_retry_wait: 100
        )

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, other_client} = :gen_tcp.connect(:localhost, port, active: false)

      :ok = :gen_tcp.send(client, "HELLO")
      :ok = :gen_tcp.send(other_client, "BONJOUR")

      # Give things enough time to send if they were going to
      Process.sleep(100)

      # Ensure that we haven't received anything on the second connection yet
      assert :gen_tcp.recv(other_client, 0, 10) == {:error, :timeout}
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

      # Give things enough time for the second connection to time out
      Process.sleep(500)

      # Ensure that the first connection is still open and the second connection closed
      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}
      assert :gen_tcp.recv(other_client, 0) == {:error, :closed}
      :gen_tcp.close(other_client)

      # Close the first connection and ensure new connections are now accepted
      :gen_tcp.close(client)

      # Give things enough time for the first connection to time out
      Process.sleep(500)

      {:ok, third_client} = :gen_tcp.connect(:localhost, port, active: false)
      :ok = :gen_tcp.send(third_client, "BUONGIORNO")

      # Give things enough time to send if they were going to
      Process.sleep(100)

      assert :gen_tcp.recv(third_client, 0) == {:ok, ~c"BUONGIORNO"}
    end

    test "should emit telemetry events as expected" do
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector, [[:thousand_island, :acceptor, :spawn_error]]}
        )

      {:ok, _, port} =
        start_handler(LongEcho,
          num_acceptors: 1,
          num_connections: 1,
          max_connections_retry_wait: 100
        )

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, other_client} = :gen_tcp.connect(:localhost, port, active: false)

      :ok = :gen_tcp.send(client, "HELLO")
      :ok = :gen_tcp.send(other_client, "BONJOUR")

      # Give things enough time for the second connection to time out
      Process.sleep(700)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :acceptor, :spawn_error], %{monotonic_time: integer()},
                %{telemetry_span_context: reference()}}
             ]
    end
  end

  test "should enumerate active connection processes" do
    {:ok, server_pid, port} = start_handler(Whoami)
    {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
    {:ok, other_client} = :gen_tcp.connect(:localhost, port, active: false)

    {:ok, pid_1} = :gen_tcp.recv(client, 0)
    {:ok, pid_2} = :gen_tcp.recv(other_client, 0)
    pid_1 = :erlang.list_to_pid(pid_1)
    pid_2 = :erlang.list_to_pid(pid_2)

    {:ok, pids} = ThousandIsland.connection_pids(server_pid)
    assert Enum.sort(pids) == Enum.sort([pid_1, pid_2])

    :gen_tcp.close(client)
    Process.sleep(100)

    assert {:ok, [pid_2]} == ThousandIsland.connection_pids(server_pid)

    :gen_tcp.close(other_client)
    Process.sleep(100)

    assert {:ok, []} == ThousandIsland.connection_pids(server_pid)
  end

  describe "suspend / resume" do
    test "suspend should stop accepting connections but keep existing ones open" do
      {:ok, server_pid, port} = start_handler(LongEcho, port: 9999)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Make sure the socket has transitioned ownership to the connection process
      Process.sleep(100)

      :ok = ThousandIsland.suspend(server_pid)

      # New connections should fail
      assert :gen_tcp.connect(:localhost, port, [active: false], 100) == {:error, :econnrefused}

      # But existing ones should still be open
      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

      # Now we resume the server
      :ok = ThousandIsland.resume(server_pid)

      # New connections should succeed
      {:ok, new_client} = :gen_tcp.connect(:localhost, port, active: false)
      :ok = :gen_tcp.send(new_client, "HELLO")
      assert :gen_tcp.recv(new_client, 0) == {:ok, ~c"HELLO"}
      :gen_tcp.close(new_client)

      # And existing ones should still be open
      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}
      :gen_tcp.close(client)
    end
  end

  describe "shutdown" do
    test "it should stop accepting connections but allow existing ones to complete" do
      {:ok, server_pid, port} = start_handler(Echo)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Make sure the socket has transitioned ownership to the connection process
      Process.sleep(100)
      task = Task.async(fn -> ThousandIsland.stop(server_pid) end)
      # Make sure that the stop has had a chance to shutdown the acceptors
      Process.sleep(100)

      assert :gen_tcp.connect(:localhost, port, [active: false], 100) == {:error, :econnrefused}

      :ok = :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}
      :gen_tcp.close(client)

      Task.await(task)

      refute Process.alive?(server_pid)
    end

    test "it should give connections a chance to say goodbye" do
      {:ok, server_pid, port} = start_handler(Goodbye)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Make sure the socket has transitioned ownership to the connection process
      Process.sleep(100)
      task = Task.async(fn -> ThousandIsland.stop(server_pid) end)
      # Make sure that the stop has had a chance to shutdown the acceptors
      Process.sleep(100)

      assert :gen_tcp.recv(client, 0) == {:ok, ~c"GOODBYE"}
      :gen_tcp.close(client)

      Task.await(task)

      refute Process.alive?(server_pid)
    end

    test "it should still work after a suspend / resume cycle" do
      {:ok, server_pid, port} = start_handler(Goodbye)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Make sure the socket has transitioned ownership to the connection process
      Process.sleep(100)

      :ok = ThousandIsland.suspend(server_pid)
      :ok = ThousandIsland.resume(server_pid)

      task = Task.async(fn -> ThousandIsland.stop(server_pid) end)
      # Make sure that the stop has had a chance to shutdown the acceptors
      Process.sleep(100)

      assert :gen_tcp.recv(client, 0) == {:ok, ~c"GOODBYE"}
      :gen_tcp.close(client)

      Task.await(task)

      refute Process.alive?(server_pid)
    end

    test "it should forcibly shutdown connections after shutdown_timeout" do
      {:ok, server_pid, port} = start_handler(Echo, shutdown_timeout: 500)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Make sure the socket has transitioned ownership to the connection process
      Process.sleep(100)
      task = Task.async(fn -> ThousandIsland.stop(server_pid) end)
      # Make sure that the stop is still waiting on the open client, and the client is still alive
      Process.sleep(100)
      assert Process.alive?(server_pid)
      :gen_tcp.send(client, "HELLO")
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

      # Make sure that the stop finished by shutdown_timeout
      Process.sleep(500)
      refute Process.alive?(server_pid)

      # Clean up by waiting on the shutdown task
      Task.await(task)
    end

    test "it should emit telemetry events as expected" do
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector,
           [
             [:thousand_island, :listener, :start],
             [:thousand_island, :listener, :stop],
             [:thousand_island, :acceptor, :start],
             [:thousand_island, :acceptor, :stop]
           ]}
        )

      {:ok, server_pid, _} = start_handler(Echo, num_acceptors: 1)

      ThousandIsland.stop(server_pid)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :listener, :start], %{monotonic_time: integer()},
                %{
                  telemetry_span_context: reference(),
                  local_address: {0, 0, 0, 0},
                  local_port: integer(),
                  transport_module: ThousandIsland.Transports.TCP,
                  transport_options: []
                }},
               {[:thousand_island, :acceptor, :start], %{monotonic_time: integer()},
                %{telemetry_span_context: reference(), parent_telemetry_span_context: reference()}},
               {[:thousand_island, :listener, :stop],
                %{duration: integer(), monotonic_time: integer()},
                %{
                  telemetry_span_context: reference(),
                  local_address: {0, 0, 0, 0},
                  local_port: integer(),
                  transport_module: ThousandIsland.Transports.TCP,
                  transport_options: []
                }},
               {[:thousand_island, :acceptor, :stop],
                %{connections: 0, duration: integer(), monotonic_time: integer()},
                %{telemetry_span_context: reference(), parent_telemetry_span_context: reference()}}
             ]
    end
  end

  describe "configuration" do
    test "tcp should allow default options to be overridden" do
      {:ok, _, port} = start_handler(ReadOpt, transport_options: [send_timeout: 1230])
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "send_timeout")
      {:ok, ~c"{:ok, [send_timeout: 1230]}"} = :gen_tcp.recv(client, 0, 100)
    end

    test "tcp should not allow hardcoded options to be overridden" do
      {:ok, _, port} = start_handler(ReadOpt, transport_options: [mode: :list])
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "mode")
      {:ok, ~c"{:ok, [mode: :binary]}"} = :gen_tcp.recv(client, 0, 100)
    end

    test "tcp should allow Erlang style bare options" do
      {:ok, _, port} = start_handler(Echo, transport_options: [:inet6])
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "HI")
      {:ok, ~c"HI"} = :gen_tcp.recv(client, 0, 100)
    end

    test "ssl should allow default options to be overridden" do
      {:ok, _, port} =
        start_handler(ReadOpt,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            send_timeout: 1230,
            certfile: Path.join(__DIR__, "../support/cert.pem"),
            keyfile: Path.join(__DIR__, "../support/key.pem")
          ]
        )

      {:ok, client} =
        :ssl.connect(:localhost, port,
          active: false,
          verify: :verify_none,
          cacertfile: Path.join(__DIR__, "../support/ca.pem")
        )

      :ssl.send(client, "send_timeout")
      {:ok, ~c"{:ok, [send_timeout: 1230]}"} = :ssl.recv(client, 0, 100)
    end

    test "ssl should not allow hardcoded options to be overridden" do
      {:ok, _, port} =
        start_handler(ReadOpt,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            mode: :list,
            certfile: Path.join(__DIR__, "../support/cert.pem"),
            keyfile: Path.join(__DIR__, "../support/key.pem")
          ]
        )

      {:ok, client} =
        :ssl.connect(:localhost, port,
          active: false,
          verify: :verify_none,
          cacertfile: Path.join(__DIR__, "../support/ca.pem")
        )

      :ssl.send(client, "mode")
      {:ok, ~c"{:ok, [mode: :binary]}"} = :ssl.recv(client, 0, 100)
    end

    test "ssl should allow Erlang style bare options" do
      {:ok, _, port} =
        start_handler(Echo,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options:
            [:inet6] ++
              [
                certfile: Path.join(__DIR__, "../support/cert.pem"),
                keyfile: Path.join(__DIR__, "../support/key.pem")
              ]
        )

      {:ok, client} =
        :ssl.connect(:localhost, port,
          active: false,
          verify: :verify_none,
          cacertfile: Path.join(__DIR__, "../support/ca.pem")
        )

      :ssl.send(client, "HI")
      {:ok, ~c"HI"} = :ssl.recv(client, 0, 100)
    end
  end

  describe "invalid configuration" do
    @tag capture_log: true
    test "it should error if a certificate is not found" do
      {:ok, server_pid, port} =
        start_handler(Error,
          handler_options: [test_pid: self()],
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            certfile: Path.join(__DIR__, "./not/a/cert.pem"),
            keyfile: Path.join(__DIR__, "./not/a/key.pem"),
            alpn_preferred_protocols: ["foo"]
          ]
        )

      {:error, _} =
        :ssl.connect(~c"localhost", port,
          active: false,
          verify: :verify_peer,
          cacertfile: Path.join(__DIR__, "../support/ca.pem")
        )

      Process.sleep(500)

      ThousandIsland.stop(server_pid)

      assert_received {:options, {:certfile, _, _}}
    end

    @tag capture_log: true
    test "handshake should fail if the client offers only unsupported ciphers" do
      server_args = [
        port: 0,
        handler_module: Error,
        handler_options: [test_pid: self()],
        transport_module: ThousandIsland.Transports.SSL,
        transport_options: [
          certfile: Path.join(__DIR__, "../support/cert.pem"),
          keyfile: Path.join(__DIR__, "../support/key.pem"),
          alpn_preferred_protocols: ["foo"]
        ]
      ]

      {:ok, server_pid} = start_supervised({ThousandIsland, server_args})
      {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)

      {:error, _} =
        :ssl.connect(~c"localhost", port,
          active: false,
          verify: :verify_peer,
          cacertfile: Path.join(__DIR__, "../support/ca.pem"),
          ciphers: [
            %{cipher: :rc4_128, key_exchange: :rsa, mac: :md5, prf: :default_prf}
          ]
        )

      Process.sleep(500)

      ThousandIsland.stop(server_pid)

      assert_received {:tls_alert, {:insufficient_security, _}}
    end
  end

  defp start_handler(handler, opts \\ []) do
    resolved_args = opts |> Keyword.put_new(:port, 0) |> Keyword.put(:handler_module, handler)
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, server_pid, port}
  end
end
