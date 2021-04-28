defmodule ThousandIsland.SocketTest do
  # False due to telemetry raciness
  use ExUnit.Case, async: false

  alias ThousandIsland.Handlers

  def gen_tcp_setup(_context) do
    {:ok, %{client_mod: :gen_tcp, server_opts: []}}
  end

  def ssl_setup(_context) do
    {:ok,
     %{
       client_mod: :ssl,
       server_opts: [
         transport_module: ThousandIsland.Transports.SSL,
         transport_options: [
           certfile: Path.join(__DIR__, "../support/cert.pem"),
           keyfile: Path.join(__DIR__, "../support/key.pem")
         ]
       ]
     }}
  end

  [:gen_tcp_setup, :ssl_setup]
  |> Enum.each(fn setup_fn ->
    describe "common behaviour using #{setup_fn}" do
      setup setup_fn

      test "should send and receive", context do
        {:ok, port} = start_handler(Handlers.Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.send(client, "HELLO") == :ok
        assert context.client_mod.recv(client, 0) == {:ok, 'HELLO'}
      end

      test "it should send files", context do
        {:ok, port} = start_handler(Handlers.Sendfile, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.recv(client, 9) == {:ok, 'ABCDEFBCD'}
      end

      test "it should close connections", context do
        {:ok, port} = start_handler(Handlers.Closer, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.recv(client, 0) == {:error, :closed}
      end

      test "it should emit telemetry events as expected", context do
        {:ok, collector_pid} = start_collector()
        {:ok, port} = start_handler(Handlers.SyncEcho, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        :ok = context.client_mod.send(client, "HELLO")
        {:ok, 'HELLO'} = context.client_mod.recv(client, 0)
        context.client_mod.close(client)

        # Give the server process a chance to shut down
        Process.sleep(100)

        events = ThousandIsland.TelemetryCollector.get_events(collector_pid)
        assert length(events) == 3
        assert {[:socket, :recv], %{result: {:ok, "HELLO"}}, _} = Enum.at(events, 0)
        assert {[:socket, :send], %{data: "HELLO", result: :ok}, _} = Enum.at(events, 1)

        assert {[:socket, :close],
                %{octets_recv: _, octets_sent: _, packets_recv: _, packets_sent: _},
                %{}} = Enum.at(events, 2)
      end
    end
  end)

  describe "behaviour specific to gen_tcp" do
    setup :gen_tcp_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Handlers.Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(:localhost, port, active: false)
      {:ok, resp} = context.client_mod.recv(client, 0)
      {:ok, local_port} = :inet.port(client)

      expected = [
        %{address: "127.0.0.1", port: port, ssl_cert: nil},
        %{address: "127.0.0.1", port: local_port, ssl_cert: nil}
      ]

      assert to_string(resp) == inspect(expected)

      context.client_mod.close(client)
    end
  end

  describe "behaviour specific to ssl" do
    setup :ssl_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Handlers.Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(:localhost, port, active: false)
      {:ok, {_, local_port}} = context.client_mod.sockname(client)
      {:ok, resp} = context.client_mod.recv(client, 0)

      expected = [
        %{address: "127.0.0.1", port: port, ssl_cert: nil},
        %{address: "127.0.0.1", port: local_port, ssl_cert: nil}
      ]

      assert to_string(resp) == inspect(expected)

      context.client_mod.close(client)
    end
  end

  defp start_handler(handler, server_args) do
    resolved_args = server_args |> Keyword.merge(port: 0, handler_module: handler)
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    ThousandIsland.local_port(server_pid)
  end

  defp start_collector do
    start_supervised(
      {ThousandIsland.TelemetryCollector, [[:socket, :recv], [:socket, :send], [:socket, :close]]}
    )
  end
end
