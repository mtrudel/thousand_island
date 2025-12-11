defmodule ThousandIsland.ProcessLabelTest do
  use ExUnit.Case, async: true

  # Process.set_label/1 was introduced in Elixir 1.17.0 and OTP 27
  @supports_labels Version.match?(System.version(), ">= 1.17.0") and
                     String.to_integer(System.otp_release()) >= 27

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

  if @supports_labels do
    test "connection handler processes should have correct labels" do
      {:ok, server_pid, _port} = start_handler(LongEcho)
      {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
      {:ok, client} = :gen_tcp.connect(~c"localhost", port, active: false)

      # Send data to establish connection
      :ok = :gen_tcp.send(client, "HELLO")
      Process.sleep(50)

      {:ok, [connection_pid]} = ThousandIsland.connection_pids(server_pid)
      label = get_process_label(connection_pid)

      assert {:thousand_island, :connection, {_config_part, {remote_ip, remote_port}}} = label
      assert is_tuple(remote_ip)
      assert is_integer(remote_port)

      :gen_tcp.close(client)
    end

    test "listener process should have correct label" do
      {:ok, server_pid, _port} = start_handler(Echo)

      listener_pid = ThousandIsland.Server.listener_pid(server_pid)
      assert listener_pid != nil

      label = get_process_label(listener_pid)

      assert {:thousand_island, :listener, _config_part} = label
    end

    test "acceptor processes should have correct labels" do
      {:ok, server_pid, _port} = start_handler(Echo, num_acceptors: 3)

      acceptor_ids =
        server_pid
        |> find_acceptor_pids()
        |> Enum.map(&get_process_label/1)
        |> Enum.map(fn {:thousand_island, :acceptor, {_config_part, id}} ->
          id
        end)
        |> Enum.sort()

      assert acceptor_ids == [1, 2, 3]
    end

    test "shutdown_listener process should have correct label" do
      {:ok, server_pid, _port} = start_handler(Echo)

      shutdown_listener_pid = find_child_by_id(server_pid, :shutdown_listener)
      assert shutdown_listener_pid != nil

      Process.sleep(100)

      label = get_process_label(shutdown_listener_pid)

      assert {:thousand_island, :shutdown_listener, _config_part} = label
    end

    test "labels persist across multiple connections" do
      {:ok, server_pid, _port} = start_handler(LongEcho)
      {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)

      # First connection
      {:ok, client1} = :gen_tcp.connect(~c"localhost", port, active: false)
      :ok = :gen_tcp.send(client1, "HELLO")
      {:ok, ~c"HELLO"} = :gen_tcp.recv(client1, 0)
      :gen_tcp.close(client1)

      Process.sleep(100)

      # Second connection
      {:ok, client2} = :gen_tcp.connect(~c"localhost", port, active: false)
      :ok = :gen_tcp.send(client2, "WORLD")
      Process.sleep(50)

      {:ok, [connection_pid]} = ThousandIsland.connection_pids(server_pid)
      label = get_process_label(connection_pid)

      assert {:thousand_island, :connection, {_config_part, _remote_info}} = label

      {:ok, ~c"WORLD"} = :gen_tcp.recv(client2, 0)
      :gen_tcp.close(client2)
    end

    test "server process should have correct label" do
      {:ok, server_pid, _port} = start_handler(Echo)

      # Check the server process label (uses configured port, which is 0 for dynamic assignment)
      label = get_process_label(server_pid)
      config_part = {0, ThousandIsland.ProcessLabelTest.Echo}
      assert label == {:thousand_island, :server, config_part}
    end
  else
    test "process labels are not set on Elixir < 1.17" do
      {:ok, server_pid, _port} = start_handler(LongEcho)
      {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
      {:ok, client} = :gen_tcp.connect(~c"localhost", port, active: false)

      # Make sure the connection is established
      :ok = :gen_tcp.send(client, "HELLO")
      Process.sleep(50)

      {:ok, [connection_pid]} = ThousandIsland.connection_pids(server_pid)

      # On older Elixir versions, :label key should not exist
      label = get_process_label(connection_pid)
      assert label == nil

      {:ok, ~c"HELLO"} = :gen_tcp.recv(client, 0)
      :gen_tcp.close(client)
    end
  end

  # Helper functions

  defp get_process_label(pid) do
    if @supports_labels do
      # On Elixir >= 1.17 / OTP >= 27, we can safely call Process.info(pid, :label)
      case Process.info(pid, :label) do
        {:label, label} -> label
        nil -> nil
      end
    else
      # On older versions, :label key doesn't exist in Process.info
      # We need to check if it's in the full process info
      case Process.info(pid) do
        nil -> nil
        info when is_list(info) -> Keyword.get(info, :label)
      end
    end
  end

  defp start_handler(handler, opts \\ []) do
    resolved_args = opts |> Keyword.put_new(:port, 0) |> Keyword.put(:handler_module, handler)
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, server_pid, port}
  end

  defp find_child_by_id(supervisor_pid, child_id) do
    supervisor_pid
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {^child_id, pid, _, _} when is_pid(pid) -> pid
      _ -> nil
    end)
  end

  defp find_acceptor_pids(server_pid) do
    child_pid = fn {_, pid, _, _} -> pid end
    # Find the AcceptorPoolSupervisor using the Server module's helper
    # Get all AcceptorSupervisors
    # For each AcceptorSupervisor, find the Acceptor (Task) process
    # The AcceptorSupervisor has 2 children: the Acceptor Task and a DynamicSupervisor
    # We want the Task (worker type)
    server_pid
    |> ThousandIsland.Server.acceptor_pool_supervisor_pid()
    |> DynamicSupervisor.which_children()
    |> Enum.map(child_pid)
    |> Enum.flat_map(fn sup_pid ->
      Supervisor.which_children(sup_pid)
      |> Enum.filter(fn
        {_id, pid, :worker, _modules} when is_pid(pid) -> true
        _ -> false
      end)
      |> Enum.map(child_pid)
    end)
  end
end
