defmodule ThousandIsland.SocketTest do
  # False due to telemetry raciness
  use ExUnit.Case, async: false

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
      {:ok, :close, state}
    end
  end

  defmodule Sendfile do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      ThousandIsland.Socket.sendfile(socket, Path.join(__DIR__, "../support/sendfile"), 0, 6)
      ThousandIsland.Socket.sendfile(socket, Path.join(__DIR__, "../support/sendfile"), 1, 3)
      {:ok, :close, state}
    end
  end

  defmodule Closer do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(_socket, state) do
      {:ok, :close, state}
    end
  end

  defmodule Info do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      peer_info = ThousandIsland.Socket.peer_info(socket)
      local_info = ThousandIsland.Socket.local_info(socket)
      negotiated_protocol = ThousandIsland.Socket.negotiated_protocol(socket)

      ThousandIsland.Socket.send(
        socket,
        "#{inspect([local_info, peer_info, negotiated_protocol])}"
      )

      {:ok, :close, state}
    end
  end

  [:gen_tcp_setup, :ssl_setup]
  |> Enum.each(fn setup_fn ->
    describe "common behaviour using #{setup_fn}" do
      setup setup_fn

      test "should send and receive", context do
        {:ok, port} = start_handler(Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.send(client, "HELLO") == :ok
        assert context.client_mod.recv(client, 0) == {:ok, 'HELLO'}
      end

      test "it should send files", context do
        {:ok, port} = start_handler(Sendfile, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.recv(client, 9) == {:ok, 'ABCDEFBCD'}
      end

      test "it should close connections", context do
        {:ok, port} = start_handler(Closer, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.recv(client, 0) == {:error, :closed}
      end

      test "it should emit telemetry events as expected", context do
        {:ok, collector_pid} = start_collector()
        {:ok, port} = start_handler(Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        :ok = context.client_mod.send(client, "HELLO")
        {:ok, 'HELLO'} = context.client_mod.recv(client, 0)
        context.client_mod.close(client)

        # Give the server process a chance to shut down
        Process.sleep(100)

        events = ThousandIsland.TelemetryCollector.get_events(collector_pid)
        assert length(events) == 4
        assert {[:socket, :handshake], %{}, _} = Enum.at(events, 0)
        assert {[:socket, :recv], %{result: {:ok, "HELLO"}}, _} = Enum.at(events, 1)
        assert {[:socket, :send], %{data: "HELLO", result: :ok}, _} = Enum.at(events, 2)

        assert {[:socket, :close],
                %{octets_recv: _, octets_sent: _, packets_recv: _, packets_sent: _},
                %{}} = Enum.at(events, 3)
      end
    end
  end)

  describe "behaviour specific to gen_tcp" do
    setup :gen_tcp_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(:localhost, port, active: false)
      {:ok, resp} = context.client_mod.recv(client, 0)
      {:ok, local_port} = :inet.port(client)

      expected = [
        %{address: {127, 0, 0, 1}, port: port, ssl_cert: nil},
        %{address: {127, 0, 0, 1}, port: local_port, ssl_cert: nil},
        {:error, :protocol_not_negotiated}
      ]

      assert to_string(resp) == inspect(expected)

      context.client_mod.close(client)
    end
  end

  describe "behaviour specific to ssl" do
    setup :ssl_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Info, context.server_opts)

      {:ok, client} =
        context.client_mod.connect(:localhost, port,
          active: false,
          alpn_advertised_protocols: ["foo"]
        )

      {:ok, {_, local_port}} = context.client_mod.sockname(client)
      {:ok, resp} = context.client_mod.recv(client, 0)

      expected = [
        %{address: {127, 0, 0, 1}, port: port, ssl_cert: nil},
        %{address: {127, 0, 0, 1}, port: local_port, ssl_cert: nil},
        {:ok, "foo"}
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
      {ThousandIsland.TelemetryCollector,
       [
         [:socket, :handshake],
         [:socket, :recv],
         [:socket, :send],
         [:socket, :sendfile],
         [:socket, :shutdown],
         [:socket, :close]
       ]}
    )
  end
end
