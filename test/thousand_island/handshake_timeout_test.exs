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

  defp ssl_opts do
    [
      certfile: Path.join(__DIR__, "../support/cert.pem"),
      keyfile: Path.join(__DIR__, "../support/key.pem")
    ]
  end

  defp start_ssl(opts) do
    args =
      [
        port: 0,
        handler_module: Echo,
        transport_module: ThousandIsland.Transports.SSL,
        transport_options: ssl_opts()
      ]
      |> Keyword.merge(opts)

    {:ok, server_pid} = start_supervised({ThousandIsland, args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {server_pid, port}
  end

  defp wait_until(fun, timeout) when timeout <= 0, do: fun.()

  defp wait_until(fun, timeout) do
    if fun.() do
      true
    else
      Process.sleep(25)
      wait_until(fun, timeout - 25)
    end
  end

  test "a client that never completes the TLS handshake is dropped after handshake_timeout" do
    {server_pid, port} = start_ssl(handshake_timeout: 200)

    # Connect at the plain-TCP level and send nothing, stalling the TLS
    # handshake indefinitely
    {:ok, client} = :gen_tcp.connect(:localhost, port, [:binary, active: false])

    # While the handshake is pending, the client occupies a connection process
    assert wait_until(
             fn -> match?({:ok, [_pid]}, ThousandIsland.connection_pids(server_pid)) end,
             500
           )

    # Once handshake_timeout lapses the server must actively close the socket...
    assert {:error, :closed} = :gen_tcp.recv(client, 0, 1000)

    # ...and release the connection process (and with it the connection slot)
    assert wait_until(fn -> ThousandIsland.connection_pids(server_pid) == {:ok, []} end, 500)
  end

  test "a well-behaved TLS client still completes the handshake and is served" do
    {_server_pid, port} = start_ssl(handshake_timeout: 200)

    {:ok, client} =
      :ssl.connect(:localhost, port,
        active: false,
        verify: :verify_none,
        cacertfile: Path.join(__DIR__, "../support/ca.pem")
      )

    :ok = :ssl.send(client, "HELLO")
    assert :ssl.recv(client, 0, 1000) == {:ok, ~c"HELLO"}
    :ssl.close(client)
  end

  test "handshake_timeout defaults to a finite value rather than :infinity" do
    config = ThousandIsland.ServerConfig.new(handler_module: Echo)
    assert is_integer(config.handshake_timeout)
    assert config.handshake_timeout > 0
  end
end
