defmodule ThousandIsland.ConnectionTest do
  use ExUnit.Case, async: true

  defmodule OwnershipErrorTransport do
    @behaviour ThousandIsland.Transport

    @impl true
    def controlling_process(socket, pid) do
      Kernel.send(socket.test_pid, {:controlling_process, socket.ref, pid})
      {:error, socket.reason}
    end

    @impl true
    def close(socket) do
      Kernel.send(socket.test_pid, {:socket_closed, socket.ref})
      :ok
    end

    @impl true
    def listen(_port, _options), do: {:error, :enotsup}
    @impl true
    def accept(_listener), do: {:error, :enotsup}
    @impl true
    def handshake(socket), do: {:ok, socket}
    @impl true
    def upgrade(_socket, _options), do: {:error, :unsupported_upgrade}
    @impl true
    def recv(_socket, _length, _timeout), do: {:error, :enotsup}
    @impl true
    def send(_socket, _data), do: {:error, :enotsup}
    @impl true
    def sendfile(_socket, _filename, _offset, _length), do: {:error, :enotsup}
    @impl true
    def getopts(_socket, _options), do: {:error, :enotsup}
    @impl true
    def setopts(_socket, _options), do: {:error, :enotsup}
    @impl true
    def shutdown(_socket, _way), do: {:error, :enotsup}
    @impl true
    def sockname(_socket), do: {:error, :enotsup}
    @impl true
    def peername(_socket), do: {:error, :enotsup}
    @impl true
    def peercert(_socket), do: {:error, :not_secure}
    @impl true
    def secure?, do: false
    @impl true
    def getstat(_socket), do: {:error, :enotsup}
    @impl true
    def negotiated_protocol(_socket), do: {:error, :protocol_not_negotiated}
    @impl true
    def connection_information(_socket), do: {:error, :not_secure}
  end

  defmodule WaitingHandler do
    use GenServer, restart: :temporary

    def start_link({test_pid, genserver_options}) do
      GenServer.start_link(__MODULE__, test_pid, genserver_options)
    end

    @impl true
    def init(test_pid) do
      Process.flag(:trap_exit, true)
      send(test_pid, {:handler_started, self()})
      {:ok, test_pid}
    end

    @impl true
    def handle_info({:thousand_island_ready, _, _, _, _}, test_pid) do
      send(test_pid, {:handler_ready, self()})
      {:noreply, test_pid}
    end

    @impl true
    def terminate(reason, test_pid) do
      send(test_pid, {:handler_terminated, self(), reason})
      :ok
    end
  end

  test "an ownership transfer error closes the socket and terminates the idle handler" do
    supervisor = start_supervised!({DynamicSupervisor, strategy: :one_for_one})

    server_config = %ThousandIsland.ServerConfig{
      handler_module: WaitingHandler,
      handler_options: self(),
      shutdown_timeout: 1_000
    }

    handler_config = %ThousandIsland.HandlerConfig{
      handler_module: WaitingHandler,
      transport_module: OwnershipErrorTransport,
      read_timeout: 1_000,
      handshake_timeout: 1_000,
      silent_terminate_on_error: false
    }

    socket_ref = make_ref()
    raw_socket = %{test_pid: self(), ref: socket_ref, reason: :badarg}

    assert {:error, {:controlling_process, :badarg}} =
             ThousandIsland.Connection.start(
               supervisor,
               raw_socket,
               server_config,
               handler_config,
               make_ref()
             )

    assert_receive {:handler_started, handler_pid}
    assert_receive {:controlling_process, ^socket_ref, ^handler_pid}
    assert_receive {:socket_closed, ^socket_ref}
    assert_receive {:handler_terminated, ^handler_pid, :shutdown}
    refute_receive {:handler_ready, ^handler_pid}

    refute Process.alive?(handler_pid)
    assert DynamicSupervisor.which_children(supervisor) == []
  end
end
