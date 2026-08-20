defmodule ThousandIsland.AcceptorTest do
  use ExUnit.Case, async: false

  use Machete

  # A transport that delegates to gen_tcp but lets the test inject a queue of
  # accept/1 results via :persistent_term, so we can simulate the OS reporting
  # file descriptor exhaustion. Once the queue is drained, real accepts resume.
  defmodule FlakyTransport do
    @behaviour ThousandIsland.Transport

    def set_accept_results(key, results), do: :persistent_term.put({__MODULE__, key}, results)

    @impl true
    def listen(port, _opts),
      do: :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])

    @impl true
    def accept(listener_socket) do
      key = :persistent_term.get({__MODULE__, :key})

      case :persistent_term.get({__MODULE__, key}, []) do
        [next | rest] ->
          :persistent_term.put({__MODULE__, key}, rest)
          # Inject a simulated error without consuming a real connection
          {:error, next}

        [] ->
          :gen_tcp.accept(listener_socket)
      end
    end

    @impl true
    def handshake(socket), do: {:ok, socket}
    @impl true
    def upgrade(_socket, _opts), do: {:error, :unsupported_upgrade}
    @impl true
    def controlling_process(socket, pid), do: :gen_tcp.controlling_process(socket, pid)
    @impl true
    def recv(socket, length, timeout), do: :gen_tcp.recv(socket, length, timeout)
    @impl true
    def send(socket, data), do: :gen_tcp.send(socket, data)
    @impl true
    def sendfile(_s, _f, _o, _l), do: {:error, :not_supported}
    @impl true
    def getopts(socket, options), do: :inet.getopts(socket, options)
    @impl true
    def setopts(socket, options), do: :inet.setopts(socket, options)
    @impl true
    def shutdown(socket, way), do: :gen_tcp.shutdown(socket, way)
    @impl true
    def close(socket), do: :gen_tcp.close(socket)
    @impl true
    def sockname(socket), do: :inet.sockname(socket)
    @impl true
    def peername(socket), do: :inet.peername(socket)
    @impl true
    def peercert(_socket), do: {:error, :not_secure}
    @impl true
    def secure?, do: false
    @impl true
    def getstat(socket), do: :inet.getstat(socket)
    @impl true
    def negotiated_protocol(_socket), do: {:error, :protocol_not_negotiated}
    @impl true
    def connection_information(_socket), do: {:error, :not_secure}
  end

  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      ThousandIsland.Socket.send(socket, data)
      {:continue, state}
    end
  end

  defp acceptor_sup_pids(server_pid) do
    server_pid
    |> ThousandIsland.Server.acceptor_pool_supervisor_pid()
    |> ThousandIsland.AcceptorPoolSupervisor.acceptor_supervisor_pids()
  end

  test "descriptor exhaustion does not take down the acceptor or its in-flight connections" do
    key = make_ref()
    :persistent_term.put({FlakyTransport, :key}, key)
    FlakyTransport.set_accept_results(key, [])

    {:ok, server_pid} =
      start_supervised(
        {ThousandIsland,
         port: 0, handler_module: Echo, transport_module: FlakyTransport, num_acceptors: 1}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    [acceptor_sup] = acceptor_sup_pids(server_pid)

    # Open a connection while descriptors are still available
    {:ok, existing} = :gen_tcp.connect(:localhost, port, [:binary, active: false])
    :ok = :gen_tcp.send(existing, "FIRST")
    assert :gen_tcp.recv(existing, 0, 1000) == {:ok, "FIRST"}

    # Now have accept report descriptor exhaustion five times in a row. Five
    # failures is past the acceptor's restart budget (3 restarts in 5 seconds):
    # if each error crashes the acceptor, the crash loop takes down the
    # acceptor's supervisor, and with it every connection that acceptor is
    # currently serving
    FlakyTransport.set_accept_results(key, [:emfile, :enfile, :emfile, :enfile, :emfile])

    # A new client unblocks the acceptor's pending accept; the acceptor then
    # works through the injected errors (backing off briefly on each) before
    # settling back into normal accepts
    {:ok, fresh} = :gen_tcp.connect(:localhost, port, [:binary, active: false])
    Process.sleep(800)

    # The in-flight connections survived the exhaustion window
    :ok = :gen_tcp.send(existing, "STILL HERE")
    assert :gen_tcp.recv(existing, 0, 1000) == {:ok, "STILL HERE"}
    :ok = :gen_tcp.send(fresh, "HELLO")
    assert :gen_tcp.recv(fresh, 0, 1000) == {:ok, "HELLO"}

    # Nothing under the server was restarted, and new connections are accepted
    # now that descriptors have freed up
    assert acceptor_sup_pids(server_pid) == [acceptor_sup]
    {:ok, late} = :gen_tcp.connect(:localhost, port, [:binary, active: false])
    :ok = :gen_tcp.send(late, "LATE")
    assert :gen_tcp.recv(late, 0, 1000) == {:ok, "LATE"}

    Enum.each([existing, fresh, late], &:gen_tcp.close/1)
  end

  test "an :emfile telemetry event is emitted on descriptor exhaustion" do
    on_exit(TelemetryHelpers.attach_all_events(Echo))

    key = make_ref()
    :persistent_term.put({FlakyTransport, :key}, key)
    FlakyTransport.set_accept_results(key, [:emfile])

    {:ok, _server_pid} =
      start_supervised(
        {ThousandIsland,
         port: 0, handler_module: Echo, transport_module: FlakyTransport, num_acceptors: 1}
      )

    assert_receive {:telemetry, [:thousand_island, :acceptor, :emfile], measurements, metadata},
                   1000

    assert measurements ~> %{monotonic_time: integer(), error: :emfile}
    assert metadata ~> %{handler: Echo, telemetry_span_context: reference()}
  end
end
