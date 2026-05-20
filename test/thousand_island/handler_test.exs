defmodule ThousandIsland.HandlerTest do
  use ExUnit.Case, async: true

  use Machete

  import ExUnit.CaptureLog

  describe "state passing" do
    defmodule StatePasser do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        {:continue, state}
      end

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        {:close, state}
      end

      @impl ThousandIsland.Handler
      def handle_close(_socket, state) do
        Logger.info("Closing with #{state}")
      end
    end

    test "it should take the initial handler_options as initial state & preserve state through calls" do
      {:ok, port} = start_handler(StatePasser, handler_options: :hello)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      messages =
        capture_log(fn ->
          :gen_tcp.send(client, "ping")
          :gen_tcp.close(client)
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_close callback
      assert messages =~ "Closing with hello"
    end

    defmodule BogusState do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        send(self(), "bogus")
        {:continue, state}
      end

      def handle_info("bogus", {_socket, state}) do
        # Intentionally dropping socket here
        {:noreply, state}
      end
    end

    test "it should complain loudly if a handle_info callback returns the wrong shaped state" do
      {:ok, port} = start_handler(BogusState)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      messages =
        capture_log(fn ->
          :gen_tcp.send(client, "ping")
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed when we tried to handle_data
      # after getting a bogus state back
      assert messages =~
               "The callback's `state` doesn't match the expected `{socket, state}` form"
    end

    defmodule FakeProxy do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        send(self(), {:tcp, :othersocket, "otherdata"})
        {:continue, state}
      end

      def handle_info({:tcp, _othersocket, _otherdata}, {socket, state}) do
        ThousandIsland.Socket.send(socket, "Got other data")
        {:noreply, {socket, state}}
      end
    end

    test "it should allow tcp messages sent from other sockets to be accepted by a Handler" do
      {:ok, port} = start_handler(FakeProxy)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      assert :gen_tcp.recv(client, 14) == {:ok, ~c"Got other data"}
    end
  end

  describe "handle_connection" do
    defmodule HandleConnection.HelloWorld do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")
        {:continue, state}
      end
    end

    test "it should keep the connection open if {:continue, state} is returned" do
      {:ok, port} = start_handler(HandleConnection.HelloWorld)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}
      assert :gen_tcp.recv(client, 0, 100) == {:error, :timeout}
    end

    defmodule HandleConnection.Closer do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        {:close, state}
      end
    end

    test "it should close the connection if {:close, state} is returned" do
      {:ok, port} = start_handler(HandleConnection.Closer)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      assert :gen_tcp.recv(client, 0) == {:error, :closed}
    end

    defmodule HandleConnection.Error do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        {:error, :nope, state}
      end

      @impl ThousandIsland.Handler
      def handle_error(error, _socket, _state) do
        Logger.error("handle_error: #{error}")
      end
    end

    test "it should close the connection and call handle_error if {:error, reason, state} is returned" do
      {:ok, port} = start_handler(HandleConnection.Error)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message dispalyed by the runtime
      assert messages =~ "terminating\n** (stop) :nope"
      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
    end

    test "it should terminate silently if {:error, reason, state} is returned and the server is so configured" do
      {:ok, port} = start_handler(HandleConnection.Error, silent_terminate_on_error: true)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we did not see the message dispalyed by the runtime
      refute messages =~ "terminating\n** (stop) :nope"
      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
    end

    defmodule HandleConnection.Exploding do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, _state) do
        raise "nope"
      end

      @impl ThousandIsland.Handler
      def handle_error({error, _stacktrace}, _socket, _state) do
        Logger.error("handle_error: #{error.message}")
      end
    end

    test "it should close the connection and call handle_error if an error is raised" do
      {:ok, port} = start_handler(HandleConnection.Exploding)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message dispalyed by the runtime
      assert messages =~ "terminating\n** (RuntimeError) nope"
      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
    end

    test "it should NOT terminate silently if an error is raised even if the server is so configured" do
      {:ok, port} = start_handler(HandleConnection.Exploding, silent_terminate_on_error: true)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message dispalyed by the runtime
      assert messages =~ "terminating\n** (RuntimeError) nope"
      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
    end
  end

  describe "upgrade" do
    defmodule HandleConnection.UpgradingEcho do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")

        {:switch_transport,
         {ThousandIsland.Transports.SSL,
          certfile: Path.join(__DIR__, "../support/cert.pem"),
          keyfile: Path.join(__DIR__, "../support/key.pem")}, state}
      end

      @impl ThousandIsland.Handler
      def handle_data(data, socket, state) do
        ThousandIsland.Socket.send(socket, data)
        {:continue, state}
      end
    end

    test "it should allow upgrading the transport mid-connection when supported" do
      {:ok, port} = start_handler(HandleConnection.UpgradingEcho)

      assert {:ok, client} = :gen_tcp.connect(:localhost, port, [active: false], 100)
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

      assert {:ok, client} =
               :ssl.connect(
                 client,
                 [cacertfile: Path.join(__DIR__, "../support/ca.pem"), verify: :verify_none],
                 100
               )

      # Check that echo works over new transport
      :ssl.send(client, "Test me")
      assert :ssl.recv(client, 0) == {:ok, ~c"Test me"}
    end

    test "it should handle upgrade errors" do
      {:ok, port} =
        start_handler(HandleConnection.UpgradeError,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            certfile: Path.join(__DIR__, "../support/cert.pem"),
            keyfile: Path.join(__DIR__, "../support/key.pem"),
            alpn_preferred_protocols: ["foo"]
          ]
        )

      messages =
        capture_log(fn ->
          assert {:ok, client} =
                   :ssl.connect(
                     ~c"localhost",
                     port,
                     active: false,
                     cacertfile: Path.join(__DIR__, "../support/ca.pem"),
                     verify: :verify_peer
                   )

          assert :ssl.recv(client, 0) == {:ok, ~c"HELLO"}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: unsupported_upgrade"
    end

    defmodule HandleConnection.UpgradeError do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")

        {:switch_transport, {ThousandIsland.Transports.TCP, []}, state}
      end

      @impl ThousandIsland.Handler
      def handle_error(error, _socket, _state) do
        Logger.error("handle_error: #{error}")
      end
    end

    defmodule HandleConnection.UpgradingEchoWithContinue do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")

        {:switch_transport,
         {ThousandIsland.Transports.SSL,
          certfile: Path.join(__DIR__, "../support/cert.pem"),
          keyfile: Path.join(__DIR__, "../support/key.pem")}, state, {:continue, :keep_going}}
      end

      def handle_continue(:keep_going, state) do
        Logger.error("handle_continue")
        {:noreply, state}
      end

      @impl ThousandIsland.Handler
      def handle_data(data, socket, state) do
        ThousandIsland.Socket.send(socket, data)
        {:continue, state}
      end
    end

    test "it should allow calling handle_continue when upgrading the transport mid-connection" do
      {:ok, port} = start_handler(HandleConnection.UpgradingEchoWithContinue)

      assert {:ok, client} = :gen_tcp.connect(:localhost, port, [active: false], 100)

      messages =
        capture_log(fn ->
          assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}

          assert {:ok, client} =
                   :ssl.connect(
                     client,
                     [cacertfile: Path.join(__DIR__, "../support/ca.pem"), verify: :verify_none],
                     100
                   )

          # Check that echo works over new transport
          :ssl.send(client, "Test me")
          assert :ssl.recv(client, 0) == {:ok, ~c"Test me"}
        end)

      assert messages =~ "handle_continue"
    end
  end

  describe "handle_data" do
    defmodule HandleData.HelloWorld do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_data("ping", socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")
        {:continue, state}
      end
    end

    test "it should keep the connection open if {:continue, state} is returned" do
      {:ok, port} = start_handler(HandleData.HelloWorld)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "ping")
      assert :gen_tcp.recv(client, 0) == {:ok, ~c"HELLO"}
      assert :gen_tcp.recv(client, 0, 100) == {:error, :timeout}
    end

    defmodule HandleData.Closer do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        {:close, state}
      end
    end

    test "it should close the connection if {:close, state} is returned" do
      {:ok, port} = start_handler(HandleData.Closer)
      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "ping")
      assert :gen_tcp.recv(client, 0) == {:error, :closed}
    end

    defmodule HandleData.Error do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        {:error, :nope, state}
      end

      @impl ThousandIsland.Handler
      def handle_error(error, _socket, _state) do
        Logger.error("handle_error: #{error}")
      end
    end

    test "it should close the connection and call handle_error if {:error, reason, state} is returned" do
      {:ok, port} = start_handler(HandleData.Error)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
    end

    defmodule HandleData.Exploding do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, _state) do
        raise "nope"
      end

      @impl ThousandIsland.Handler
      def handle_error({error, _stacktrace}, _socket, _state) do
        Logger.error("handle_error: #{error.message}")
      end
    end

    test "it should close the connection and call handle_error if an error is raised" do
      {:ok, port} = start_handler(HandleData.Exploding)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
    end
  end

  describe "async waiting" do
    defmodule TimeoutInitial do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        {:continue, state, 50}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end
    end

    test "it should close the connection and call handle_timeout if the specified timeout is reached waiting for initial client data" do
      {:ok, port} = start_handler(TimeoutInitial)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_timeout callback
      assert messages =~ "handle_timeout"
    end

    defmodule TimeoutData do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        {:continue, state, 50}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end
    end

    defmodule PersistentTimeoutData do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        {:continue, state, {:persistent, 50}}
      end

      def handle_data("pong", _socket, state) do
        {:continue, state}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end
    end

    defmodule ContinueData do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        {:continue, state, {:continue, :keep_going}}
      end

      def handle_continue(:keep_going, state) do
        Logger.error("handle_continue")
        {:stop, :normal, state}
      end
    end

    test "it should close the connection and call handle_timeout if the specified timeout is reached waiting for client data" do
      {:ok, port} = start_handler(TimeoutData)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_timeout callback
      assert messages =~ "handle_timeout"
    end

    defmodule ReadTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        # Flood ourselves with local messages to verify they don't reset the
        # read timer (regression test for https://github.com/mtrudel/bandit/issues/577)
        schedule_local_ping()
        {:continue, state}
      end

      @impl ThousandIsland.Handler
      def handle_data("ping", _socket, state) do
        Logger.info("ping_received")
        {:continue, state}
      end

      def handle_info(:local_ping, {socket, state}) do
        schedule_local_ping()
        {:noreply, {socket, state}}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end

      defp schedule_local_ping, do: Process.send_after(self(), :local_ping, 10)
    end

    test "it should close the connection and call handle_timeout if the global read_timeout is reached waiting for client data" do
      # Start handler with a global read_timeout of 50ms for all connections
      read_timeout = 50
      {:ok, port} = start_handler(ReadTimeout, read_timeout: read_timeout)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0, read_timeout * 5) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure the initial message was received
      assert messages =~ "ping_received"
      # Ensure that we saw the message displayed by the handle_timeout callback,
      # even though local handle_info messages kept arriving
      assert messages =~ "handle_timeout"
    end

    @tag capture_log: true
    test "it should not close the connection if the client keeps sending within the read_timeout, even with local messages arriving" do
      read_timeout = 100
      {:ok, port} = start_handler(ReadTimeout, read_timeout: read_timeout)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Send pings every 50ms (well within the 100ms timeout) for 300ms
      for _ <- 1..6 do
        :gen_tcp.send(client, "ping")
        Process.sleep(50)
      end

      # Connection should still be open
      assert :gen_tcp.recv(client, 0, 10) == {:error, :timeout}
      :gen_tcp.close(client)
    end

    defmodule SyncReadTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", socket, state) do
        Logger.info("ping_received")

        case ThousandIsland.Socket.recv(socket, 0) do
          {:error, reason} -> {:error, reason, state}
          {:ok, _binary} -> {:continue, state}
        end
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end
    end

    test "it should timeout after the global read_timeout on synchronous recv call" do
      # Start handler with a global read_timeout of 50ms for all connections
      read_timeout = 50
      {:ok, port} = start_handler(SyncReadTimeout, read_timeout: read_timeout)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0, read_timeout * 2) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure the initial message was received
      assert messages =~ "ping_received"
      # Ensure that we saw the message displayed by the handle_timeout callback
      assert messages =~ "handle_timeout"
    end

    test "it should use the timeout from the callback functions instead of the global read_timeout if specified" do
      # TimeoutData specifies a 50ms timeout after the first ping message
      {:ok, port} = start_handler(TimeoutData, read_timeout: 500)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0, 200) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_timeout callback
      assert messages =~ "handle_timeout"
    end

    test "it should persist the timeout from the callback functions as the global read_timeout if specified" do
      # PersistentTimeoutData specifies a 50ms timeout after the first ping message
      {:ok, port} = start_handler(PersistentTimeoutData, read_timeout: 500)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          Process.sleep(100)
          :gen_tcp.send(client, "pong")
          assert :gen_tcp.recv(client, 0, 200) == {:error, :closed}
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_timeout callback
      assert messages =~ "handle_timeout"
    end

    test "it should call handle_continue from the callback functions if specified" do
      {:ok, port} = start_handler(ContinueData)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "ping")
          assert :gen_tcp.recv(client, 0, 200) == {:error, :closed}
        end)

      # Ensure that we saw the message displayed by the handle_continue callback
      assert messages =~ "handle_continue"
    end

    defmodule GenServerIdleTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        # Send ourselves a message that returns a 1ms GenServer idle timeout.
        # Prior to 1.5.0, the resulting :timeout message was indistinguishable
        # from the read timer and would call handle_timeout/2, closing the
        # connection. Under the new timer-based approach it ends up as a :timeout
        # message in our inbox and is ignored here
        send(self(), :trigger_genserver_timeout)
        {:continue, state}
      end

      def handle_info(:trigger_genserver_timeout, {socket, state}) do
        {:noreply, {socket, state}, 1}
      end

      def handle_info(:timeout, {socket, state}) do
        {:noreply, {socket, state}}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout_fired")
      end
    end

    test "it should NOT call handle_timeout when only a GenServer :timeout message fires (no client inactivity)" do
      {:ok, port} = start_handler(GenServerIdleTimeout, read_timeout: 5_000)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          # Wait well past the 1ms GenServer idle timeout
          Process.sleep(200)
          # Connection should still be alive — the :timeout message was ignored
          assert :gen_tcp.recv(client, 0, 50) == {:error, :timeout}
          :gen_tcp.close(client)
        end)

      refute messages =~ "handle_timeout_fired"
    end

    defmodule SendDoesNotAffectTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        Process.send_after(self(), :send_bytes, 1)
        {:continue, state}
      end

      def handle_info(:send_bytes, {socket, state}) do
        ThousandIsland.Socket.send(socket, "A")
        Process.send_after(self(), :send_bytes, 1)
        {:noreply, {socket, state}}
      end
    end

    test "it should still timeout after read_timeout even though the server is sending bytes" do
      {:ok, port} = start_handler(SendDoesNotAffectTimeout, read_timeout: 500)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # recv will see a bunch of separate reads, so reduce until we see a closed
      assert Stream.unfold(client, fn client ->
               case :gen_tcp.recv(client, 0, 1000) do
                 {:ok, data} -> {data, client}
                 {:error, :closed} -> nil
               end
             end)
             |> Enum.flat_map(& &1)
             |> Enum.join()
             ~> string(min: 400, max: 600)

      :gen_tcp.close(client)
    end

    defmodule LongHandlerCallbacksDoNotAffectTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data(_data, _socket, state) do
        Process.sleep(200)
        Process.send_after(self(), :send_bytes, 50)
        {:continue, state}
      end

      def handle_info(:send_bytes, {socket, state}) do
        ThousandIsland.Socket.send(socket, "A")
        {:noreply, {socket, state}}
      end
    end

    test "time spent within network-facing callbacks does not affect timeout" do
      {:ok, port} = start_handler(LongHandlerCallbacksDoNotAffectTimeout, read_timeout: 100)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "A")

      # We expect the timeout (100ms) to be larger than the 50ms callback above
      assert {:ok, ~c'A'} = :gen_tcp.recv(client, 0, 1000)

      :gen_tcp.close(client)
    end

    defmodule LongGenServerCallbacksDoAffectTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        send(self(), :sleep_then_send)
        {:continue, state}
      end

      def handle_info(:sleep_then_send, {socket, state}) do
        Process.sleep(75)

        # This should occur after the timeout
        Process.send_after(self(), :send_bytes, 50)
        {:noreply, {socket, state}}
      end

      def handle_info(:send_bytes, {socket, state}) do
        ThousandIsland.Socket.send(socket, "A")
        {:noreply, {socket, state}}
      end
    end

    test "time spent within GenServer native callbacks does affect timeout" do
      {:ok, port} = start_handler(LongGenServerCallbacksDoAffectTimeout, read_timeout: 100)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # We expect the timeout (100ms) to be larger than the 150ms sleep above
      assert {:error, :closed} = :gen_tcp.recv(client, 0, 1000)

      :gen_tcp.close(client)
    end

    defmodule LongGenServerCallbacksHaveAContinuationEscapeHatch do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        send(self(), :sleep_then_send)
        {:continue, state}
      end

      def handle_info(:sleep_then_send, {socket, state}) do
        Process.sleep(150)

        Process.send_after(self(), :send_bytes, 50)
        ThousandIsland.Handler.handle_continuation({:continue, state}, socket)
      end

      def handle_info(:send_bytes, {socket, state}) do
        ThousandIsland.Socket.send(socket, "A")
        {:noreply, {socket, state}}
      end
    end

    test "GenServer native callbacks have an escape hatch to not affect timeout" do
      {:ok, port} =
        start_handler(LongGenServerCallbacksHaveAContinuationEscapeHatch, read_timeout: 100)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # We expect the handle_continuation to reset the timeout and for the send_bytes to fire
      assert {:ok, ~c'A'} = :gen_tcp.recv(client, 0, 1000)
      assert {:error, :closed} = :gen_tcp.recv(client, 0, 1000)

      :gen_tcp.close(client)
    end

    defmodule EchoWithTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data(data, socket, state) do
        ThousandIsland.Socket.send(socket, data)
        {:continue, state}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end
    end

    #
    # Verify that the timer is properly reset each time client data arrives, so
    # the timeout is always measured from the *last* client message, not the first.
    #
    test "timer resets from the last client message, not the first" do
      read_timeout = 100
      {:ok, port} = start_handler(EchoWithTimeout, read_timeout: read_timeout)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)

      # Send several pings spread over 3x the timeout window — if the timer
      # were not resetting, we'd be closed long before the last ping
      for _ <- 1..4 do
        :gen_tcp.send(client, "ping")
        assert :gen_tcp.recv(client, 4) == {:ok, ~c"ping"}
        Process.sleep(80)
      end

      # Now stop sending; the timeout should fire from the last ping
      messages =
        capture_log(fn ->
          assert :gen_tcp.recv(client, 0, read_timeout * 3) == {:error, :closed}
          Process.sleep(50)
        end)

      assert messages =~ "handle_timeout"
    end

    defmodule OneShotTimeoutWithLocalMessages do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("start", _socket, state) do
        # Return a tight 50ms one-shot timeout, then flood with local messages
        schedule_local_message()
        {:continue, state, 50}
      end

      def handle_data(_data, _socket, state) do
        {:continue, state}
      end

      def handle_info(:local_message, {socket, state}) do
        schedule_local_message()
        {:noreply, {socket, state}}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end

      defp schedule_local_message do
        Process.send_after(self(), :local_message, 10)
      end
    end

    #
    # Verify the {:continue, state, timeout} one-shot override is applied only
    # to the next client-data window, and is not reset by local messages.
    #
    test "one-shot timeout fires based on client inactivity, not local messages" do
      {:ok, port} = start_handler(OneShotTimeoutWithLocalMessages, read_timeout: 5_000)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "start")
          # Should close well within the global 5s timeout but ~50ms after "start"
          assert :gen_tcp.recv(client, 0, 1_000) == {:error, :closed}
          Process.sleep(50)
        end)

      assert messages =~ "handle_timeout"
    end

    defmodule PersistentTimeoutWithLocalMessages do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("start", _socket, state) do
        schedule_local_message()
        {:continue, state, {:persistent, 80}}
      end

      def handle_data(_data, _socket, state) do
        schedule_local_message()
        {:continue, state}
      end

      def handle_info(:local_message, {socket, state}) do
        schedule_local_message()
        {:noreply, {socket, state}}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end

      defp schedule_local_message do
        Process.send_after(self(), :local_message, 10)
      end
    end

    #
    # Verify {:persistent, timeout} continues to apply to subsequent rounds,
    # still unaffected by local messages.
    #
    test "persistent timeout fires after client inactivity even across multiple data rounds" do
      {:ok, port} = start_handler(PersistentTimeoutWithLocalMessages, read_timeout: 5_000)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.send(client, "start")
          # Send a second message to confirm the persistent timeout carries over
          Process.sleep(40)
          :gen_tcp.send(client, "ping")
          # Now go silent; should time out ~80ms after "ping" despite local messages
          assert :gen_tcp.recv(client, 0, 1_000) == {:error, :closed}
          Process.sleep(50)
        end)

      assert messages =~ "handle_timeout"
    end

    test "a GenServer :timeout message does not trigger handle_timeout" do
      # Use a long read_timeout so it won't naturally expire during the test
      {:ok, port} = start_handler(GenServerIdleTimeout, read_timeout: 5_000)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          # Wait well past the 1ms GenServer idle timeout
          Process.sleep(200)
          # Connection should still be alive — the :timeout message was ignored
          assert :gen_tcp.recv(client, 0, 50) == {:error, :timeout}
          :gen_tcp.close(client)
        end)

      refute messages =~ "handle_timeout_fired"
    end

    defmodule DoNothing do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_close(_socket, _state) do
        Logger.error("handle_close")
      end
    end

    test "it should close the connection and call handle_close if the client closes the connection" do
      {:ok, port} = start_handler(DoNothing)

      messages =
        capture_log(fn ->
          {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
          :gen_tcp.close(client)
          Process.sleep(100)
        end)

      # Ensure that we saw the message displayed by the handle_close callback
      assert messages =~ "handle_close"
    end
  end

  describe "telemetry" do
    defmodule Telemetry.CloseOnData do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_data(_data, _socket, state) do
        {:close, state}
      end
    end

    test "it should send `start` telemetry event on startup" do
      TelemetryHelpers.attach_all_events(Telemetry.Closer)

      {:ok, port} = start_handler(Telemetry.Closer)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)

      assert_receive {:telemetry, [:thousand_island, :connection, :start], measurements,
                      metadata},
                     500

      assert measurements ~> %{monotonic_time: integer()}

      assert metadata
             ~> %{
               handler: Telemetry.Closer,
               parent_telemetry_span_context: reference(),
               remote_address: ip,
               remote_port: port,
               telemetry_span_context: reference()
             }
    end

    test "it should send `ready` telemetry event once socket is ready" do
      TelemetryHelpers.attach_all_events(Telemetry.Closer)

      {:ok, port} = start_handler(Telemetry.Closer)

      {:ok, _client} = :gen_tcp.connect(:localhost, port, active: false)

      assert_receive {:telemetry, [:thousand_island, :connection, :ready], measurements,
                      metadata},
                     500

      assert measurements ~> %{monotonic_time: integer()}
      assert metadata ~> %{handler: Telemetry.Closer, telemetry_span_context: reference()}
    end

    test "it should send `async_recv` telemetry event on async receipt of data" do
      TelemetryHelpers.attach_all_events(Telemetry.CloseOnData)

      {:ok, port} = start_handler(Telemetry.CloseOnData)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "ping")

      assert_receive {:telemetry, [:thousand_island, :connection, :async_recv], measurements,
                      metadata},
                     500

      assert measurements ~> %{data: "ping"}

      assert metadata
             ~> %{
               handler: Telemetry.CloseOnData,
               telemetry_span_context: reference()
             }
    end

    defmodule Telemetry.HelloWorld do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")
        {:continue, state}
      end
    end

    test "it should send `stop` telemetry event on client shutdown" do
      TelemetryHelpers.attach_all_events(Telemetry.HelloWorld)

      {:ok, port} = start_handler(Telemetry.HelloWorld)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)
      {:ok, ~c"HELLO"} = :gen_tcp.recv(client, 5)
      :gen_tcp.close(client)

      assert_receive {:telemetry, [:thousand_island, :connection, :stop], measurements, metadata},
                     500

      assert measurements ~> %{monotonic_time: integer(), duration: integer()}

      assert metadata
             ~> %{
               handler: Telemetry.HelloWorld,
               parent_telemetry_span_context: reference(),
               remote_address: ip,
               remote_port: port,
               telemetry_span_context: reference()
             }
    end

    defmodule Telemetry.Closer do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(socket, state) do
        ThousandIsland.Socket.send(socket, "HELLO")
        {:close, state}
      end
    end

    test "it should send `stop` telemetry event on shutdown" do
      TelemetryHelpers.attach_all_events(Telemetry.Closer)

      {:ok, port} = start_handler(Telemetry.Closer)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)

      :gen_tcp.connect(:localhost, port, active: false)

      assert_receive {:telemetry, [:thousand_island, :connection, :stop], measurements, metadata},
                     500

      assert measurements
             ~> %{
               monotonic_time: integer(),
               duration: integer(),
               recv_cnt: 0,
               recv_oct: 0,
               send_cnt: 1,
               send_oct: 5
             }

      assert metadata
             ~> %{
               handler: Telemetry.Closer,
               parent_telemetry_span_context: reference(),
               remote_address: ip,
               remote_port: port,
               telemetry_span_context: reference()
             }
    end

    defmodule Telemetry.Error do
      use ThousandIsland.Handler

      @impl ThousandIsland.Handler
      def handle_connection(_socket, state) do
        {:error, :nope, state}
      end
    end

    @tag capture_log: true
    test "it should send `stop` telemetry event with payload on error" do
      TelemetryHelpers.attach_all_events(Telemetry.Error)

      {:ok, port} = start_handler(Telemetry.Error)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)

      assert_receive {:telemetry, [:thousand_island, :connection, :stop], measurements, metadata},
                     500

      assert measurements
             ~> %{
               monotonic_time: integer(),
               duration: integer(),
               recv_cnt: 0,
               recv_oct: 0,
               send_cnt: 0,
               send_oct: 0
             }

      assert metadata
             ~> %{
               handler: Telemetry.Error,
               error: :nope,
               parent_telemetry_span_context: reference(),
               remote_address: ip,
               remote_port: port,
               telemetry_span_context: reference()
             }
    end
  end

  defp start_handler(handler, server_args \\ []) do
    resolved_args = [port: 0, handler_module: handler, num_acceptors: 1] ++ server_args
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, port}
  end
end
