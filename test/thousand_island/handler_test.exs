defmodule ThousandIsland.HandlerTest do
  # False due to telemetry raciness
  use ExUnit.Case, async: false

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
      assert :gen_tcp.recv(client, 0) == {:ok, 'HELLO'}
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

      # Ensure that we saw the message displayed by the handle_error callback
      assert messages =~ "handle_error: nope"
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
      assert :gen_tcp.recv(client, 0) == {:ok, 'HELLO'}
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
      def handle_data("ping", _socket, state) do
        Logger.info("ping_received")
        {:continue, state}
      end

      @impl ThousandIsland.Handler
      def handle_timeout(_socket, _state) do
        Logger.error("handle_timeout")
      end
    end

    test "it should close the connection and call handle_timeout if the global read_timeout is reached waiting for client data" do
      # Start handler with a global read_timeout of 50ms for all connections
      read_timeout = 50
      {:ok, port} = start_handler(ReadTimeout, read_timeout: read_timeout)

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

    defmodule SyncReadTimeout do
      use ThousandIsland.Handler

      require Logger

      @impl ThousandIsland.Handler
      def handle_data("ping", socket, state) do
        Logger.info("ping_received")

        case ThousandIsland.Socket.recv(socket, 0) do
          {:error, reason} ->
            {:error, reason, state}

          {:ok, _binary} ->
            {:continue, state}
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
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector, [[:thousand_island, :connection, :start]]}
        )

      {:ok, port} = start_handler(Telemetry.Closer)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)
      Process.sleep(100)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :connection, :start], %{monotonic_time: integer()},
                %{
                  telemetry_parent_span_context: reference(),
                  remote_address: ip,
                  remote_port: port,
                  telemetry_span_context: reference()
                }}
             ]
    end

    test "it should send `ready` telemetry event once socket is ready" do
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector, [[:thousand_island, :connection, :ready]]}
        )

      {:ok, port} = start_handler(Telemetry.Closer)

      {:ok, _client} = :gen_tcp.connect(:localhost, port, active: false)
      Process.sleep(100)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :connection, :ready], %{monotonic_time: integer()},
                %{telemetry_span_context: reference()}}
             ]
    end

    test "it should send `async_recv` telemetry event on async receipt of data" do
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector, [[:thousand_island, :connection, :async_recv]]}
        )

      {:ok, port} = start_handler(Telemetry.CloseOnData)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      :gen_tcp.send(client, "ping")
      Process.sleep(100)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :connection, :async_recv], %{data: "ping"},
                %{telemetry_span_context: reference()}}
             ]
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
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector, [[:thousand_island, :connection, :stop]]}
        )

      {:ok, port} = start_handler(Telemetry.Closer)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)

      :gen_tcp.connect(:localhost, port, active: false)
      Process.sleep(100)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :connection, :stop],
                %{
                  duration: integer(),
                  monotonic_time: integer(),
                  recv_cnt: 0,
                  recv_oct: 0,
                  send_cnt: 1,
                  send_oct: 5
                },
                %{
                  telemetry_parent_span_context: reference(),
                  remote_address: ip,
                  remote_port: port,
                  telemetry_span_context: reference()
                }}
             ]
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
      {:ok, collector_pid} =
        start_supervised(
          {ThousandIsland.TelemetryCollector, [[:thousand_island, :connection, :stop]]}
        )

      {:ok, port} = start_handler(Telemetry.Error)

      {:ok, client} = :gen_tcp.connect(:localhost, port, active: false)
      {:ok, {ip, port}} = :inet.sockname(client)
      Process.sleep(100)

      assert ThousandIsland.TelemetryCollector.get_events(collector_pid)
             ~> [
               {[:thousand_island, :connection, :stop],
                %{
                  duration: integer(),
                  monotonic_time: integer(),
                  recv_cnt: 0,
                  recv_oct: 0,
                  send_cnt: 0,
                  send_oct: 0
                },
                %{
                  error: :nope,
                  telemetry_parent_span_context: reference(),
                  remote_address: ip,
                  remote_port: port,
                  telemetry_span_context: reference()
                }}
             ]
    end
  end

  defp start_handler(handler, server_args \\ []) do
    resolved_args = [port: 0, handler_module: handler] ++ server_args
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, %{port: port}} = ThousandIsland.listener_info(server_pid)
    {:ok, port}
  end
end
