defmodule ThousandIsland.SocketTest do
  # False due to telemetry raciness
  use ExUnit.Case, async: false

  use Machete

  def gen_tcp_setup(_context) do
    {:ok, %{client_mod: :gen_tcp, client_opts: [active: false], server_opts: []}}
  end

  def ssl_setup(_context) do
    {:ok,
     %{
       client_mod: :ssl,
       client_opts: [
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

      ThousandIsland.Socket.send(
        socket,
        "#{inspect([local_info, peer_info, negotiated_protocol])}"
      )

      {:close, state}
    end
  end

  [:gen_tcp_setup, :ssl_setup]
  |> Enum.each(fn setup_fn ->
    describe "common behaviour using #{setup_fn}" do
      setup setup_fn

      test "should send and receive", context do
        {:ok, port} = start_handler(Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)

        assert context.client_mod.send(client, "HELLO") == :ok
        assert context.client_mod.recv(client, 0) == {:ok, ~c"HELLO"}
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
        {:ok, ~c"HELLO"} = context.client_mod.recv(client, 0)
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
    end
  end)

  describe "behaviour specific to gen_tcp" do
    setup :gen_tcp_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      {:ok, resp} = context.client_mod.recv(client, 0)
      {:ok, local_port} = :inet.port(client)

      expected = [
        {{127, 0, 0, 1}, port},
        {{127, 0, 0, 1}, local_port},
        {:error, :protocol_not_negotiated}
      ]

      assert to_string(resp) == inspect(expected)

      context.client_mod.close(client)
    end

    test "it should send files", context do
      server_opts = Keyword.put(context.server_opts, :handler_options, test_pid: self())
      {:ok, port} = start_handler(Sendfile, server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      assert context.client_mod.recv(client, 9) == {:ok, ~c"ABCDEFBCD"}
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

      expected = [
        {{127, 0, 0, 1}, port},
        {{127, 0, 0, 1}, local_port},
        {:ok, "foo"}
      ]

      assert to_string(resp) == inspect(expected)

      context.client_mod.close(client)
    end

    test "it should send files", context do
      server_opts = Keyword.put(context.server_opts, :handler_options, test_pid: self())
      {:ok, port} = start_handler(Sendfile, server_opts)
      {:ok, client} = context.client_mod.connect(~c"localhost", port, context.client_opts)
      assert context.client_mod.recv(client, 9) == {:ok, ~c"ABCDEFBCD"}
      assert_receive {:monitored_by, [_pid]}
    end
  end

  defp start_handler(handler, server_args) do
    resolved_args = [port: 0, handler_module: handler] ++ server_args
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, port}
  end
end
