defmodule ThousandIsland.HandshakeTelemetryTest do
  use ExUnit.Case, async: false

  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  defp attach_conn_events do
    parent = self()
    handler_id = "handshake-telemetry-#{inspect(make_ref())}"

    :telemetry.attach_many(
      handler_id,
      [
        [:thousand_island, :connection, :start],
        [:thousand_island, :connection, :stop]
      ],
      fn [_, _, kind], _measurements, _metadata, _cfg ->
        send(parent, {:conn_event, kind})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  test "a failed TLS handshake emits exactly one connection :stop span event" do
    attach_conn_events()

    {:ok, server_pid} =
      start_supervised(
        {ThousandIsland,
         port: 0,
         handler_module: Echo,
         transport_module: ThousandIsland.Transports.SSL,
         transport_options: [
           certfile: Path.join(__DIR__, "../support/cert.pem"),
           keyfile: Path.join(__DIR__, "../support/key.pem")
         ]}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)

    # Force a handshake failure by offering only an unsupported cipher
    {:error, _} =
      :ssl.connect(~c"localhost", port,
        active: false,
        verify: :verify_none,
        ciphers: [%{cipher: :rc4_128, key_exchange: :rsa, mac: :md5, prf: :default_prf}]
      )

    # Exactly one start and one stop for the single (failed) connection: spans
    # must be balanced so that consumers pairing starts with stops (or keeping
    # an active-connection gauge) stay correct
    assert_receive {:conn_event, :start}, 1000
    assert_receive {:conn_event, :stop}, 1000
    refute_receive {:conn_event, :stop}, 300
    refute_received {:conn_event, :start}
  end

  test "a normal connection still emits exactly one start and one stop" do
    attach_conn_events()

    {:ok, server_pid} = start_supervised({ThousandIsland, port: 0, handler_module: Echo})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)

    {:ok, client} = :gen_tcp.connect(:localhost, port, [:binary, active: false])
    :ok = :gen_tcp.send(client, "HELLO")
    {:ok, "HELLO"} = :gen_tcp.recv(client, 0, 1000)
    :gen_tcp.close(client)

    assert_receive {:conn_event, :start}, 1000
    assert_receive {:conn_event, :stop}, 1000
    refute_receive {:conn_event, :stop}, 300
    refute_received {:conn_event, :start}
  end
end
