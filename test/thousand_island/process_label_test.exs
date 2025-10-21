defmodule ThousandIsland.ProcessLabelTest do
  use ExUnit.Case, async: true

  # Process.set_label/1 was introduced in Elixir 1.17.0
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

      # Get connection pid while connection is still open
      {:ok, [connection_pid]} = ThousandIsland.connection_pids(server_pid)

      # Check the connection process label
      label = get_process_label(connection_pid)

      # Label format: [:thousand_island, :connection, configured_port, handler_module, {remote_ip, remote_port}]
      # Note: configured_port is 0 for dynamic port assignment
      assert [
               :thousand_island,
               :connection,
               0,
               ThousandIsland.ProcessLabelTest.LongEcho,
               {remote_ip, remote_port}
             ] = label

      assert is_tuple(remote_ip)
      assert is_integer(remote_port)

      :gen_tcp.close(client)
    end

    test "listener process should have correct label" do
      {:ok, server_pid, _port} = start_handler(Echo)
      {:ok, {_ip, actual_port}} = ThousandIsland.listener_info(server_pid)

      # Find the listener process using the Server module's helper
      listener_pid = ThousandIsland.Server.listener_pid(server_pid)
      assert listener_pid != nil

      # Check the listener process label
      label = get_process_label(listener_pid)
      # Listener gets the actual assigned port
      assert label == [
               :thousand_island,
               :listener,
               actual_port,
               ThousandIsland.ProcessLabelTest.Echo
             ]
    end

    test "acceptor processes should have correct labels" do
      {:ok, server_pid, _port} = start_handler(Echo, num_acceptors: 3)

      # Give acceptors time to start
      Process.sleep(50)

      # Find acceptor processes
      acceptor_pids = find_acceptor_pids(server_pid)
      assert length(acceptor_pids) == 3

      # Check that each acceptor has a label with an ID
      labels =
        Enum.map(acceptor_pids, fn pid ->
          get_process_label(pid)
        end)

      # Each acceptor should have: [:thousand_island, :acceptor, configured_port (0), handler_module, acceptor_id]
      acceptor_ids =
        Enum.map(labels, fn [
                              :thousand_island,
                              :acceptor,
                              0,
                              ThousandIsland.ProcessLabelTest.Echo,
                              id
                            ] ->
          id
        end)

      assert Enum.sort(acceptor_ids) == [1, 2, 3]
    end

    test "shutdown_listener process should have correct label" do
      {:ok, server_pid, _port} = start_handler(Echo)

      # Find the shutdown listener process by ID
      shutdown_listener_pid = find_child_by_id(server_pid, :shutdown_listener)
      assert shutdown_listener_pid != nil

      # Give it time to complete its setup (it sets the label in handle_continue)
      Process.sleep(100)

      # Check the shutdown listener process label
      label = get_process_label(shutdown_listener_pid)
      assert [:thousand_island, :shutdown_listener, listener_pid] = label
      assert is_pid(listener_pid)
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

      # Should have thousand_island prefix and correct format (port is 0 for dynamic assignment)
      assert [:thousand_island, :connection, 0, ThousandIsland.ProcessLabelTest.LongEcho | _] =
               label

      {:ok, ~c"WORLD"} = :gen_tcp.recv(client2, 0)
      :gen_tcp.close(client2)
    end

    test "server process should have correct label" do
      {:ok, server_pid, _port} = start_handler(Echo)

      # Check the server process label (uses configured port, which is 0 for dynamic assignment)
      label = get_process_label(server_pid)
      assert label == [:thousand_island, :server, 0, ThousandIsland.ProcessLabelTest.Echo]
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
    Supervisor.which_children(supervisor_pid)
    |> Enum.find_value(fn
      {^child_id, pid, _, _} when is_pid(pid) -> pid
      _ -> nil
    end)
  end

  defp find_acceptor_pids(server_pid) do
    # Find the AcceptorPoolSupervisor using the Server module's helper
    acceptor_pool_sup = ThousandIsland.Server.acceptor_pool_supervisor_pid(server_pid)

    # Get all AcceptorSupervisors
    acceptor_sups =
      DynamicSupervisor.which_children(acceptor_pool_sup)
      |> Enum.map(fn {_, pid, _, _} -> pid end)

    # For each AcceptorSupervisor, find the Acceptor (Task) process
    # The AcceptorSupervisor has 2 children: the Acceptor Task and a DynamicSupervisor
    # We want the Task (worker type)
    Enum.flat_map(acceptor_sups, fn sup_pid ->
      Supervisor.which_children(sup_pid)
      |> Enum.filter(fn
        {_id, pid, :worker, _modules} when is_pid(pid) -> true
        _ -> false
      end)
      |> Enum.map(fn {_, pid, _, _} -> pid end)
    end)
  end
end
