defmodule ThousandIsland.SpawnFailureTest do
  use ExUnit.Case, async: false

  use Machete

  # A handler_module (with a real child_spec via `use GenServer`) whose init
  # fails, modelling a handler that cannot start (a failed resource acquisition
  # or registry registration at connection setup time, say). The failure mode
  # is selected via handler_options.
  defmodule FailInitHandler do
    use GenServer, restart: :temporary

    def start_link({handler_options, genserver_options}),
      do: GenServer.start_link(__MODULE__, handler_options, genserver_options)

    @impl true
    def init(:stop), do: {:stop, :intentional_init_failure}
    def init(:ignore), do: :ignore
  end

  defp acceptor_pids(server_pid) do
    server_pid
    |> ThousandIsland.Server.acceptor_pool_supervisor_pid()
    |> ThousandIsland.AcceptorPoolSupervisor.acceptor_supervisor_pids()
    |> Enum.flat_map(fn sup ->
      for {:acceptor, pid, _, _} <- Supervisor.which_children(sup), is_pid(pid), do: pid
    end)
  end

  for mode <- [:stop, :ignore] do
    test "a handler whose init returns #{inspect(mode)} does not crash the acceptor, and the socket is closed" do
      {:ok, server_pid} =
        start_supervised(
          {ThousandIsland,
           port: 0,
           handler_module: FailInitHandler,
           handler_options: unquote(mode),
           num_acceptors: 1}
        )

      {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
      acceptors_before = acceptor_pids(server_pid)

      # Six connections in a row; each accept succeeds but no handler can be
      # started. Six is past the acceptor's restart budget (3 restarts in 5
      # seconds), so if each failure crashed the acceptor this would take down
      # its supervisor as well
      for _ <- 1..6 do
        {:ok, client} = :gen_tcp.connect(:localhost, port, [:binary, active: false], 1000)

        # The server must actively close the accepted socket rather than leave
        # it dangling
        assert {:error, :closed} = :gen_tcp.recv(client, 0, 1000)
        :gen_tcp.close(client)
      end

      # The very same acceptor process is still in place: it never crashed,
      # let alone escalated into its supervision tree
      assert acceptor_pids(server_pid) == acceptors_before
      assert Process.alive?(server_pid)
      assert {:ok, []} = ThousandIsland.connection_pids(server_pid)
    end
  end

  test "a spawn failure emits a spawn_error telemetry event carrying the reason" do
    on_exit(TelemetryHelpers.attach_all_events(FailInitHandler))

    {:ok, server_pid} =
      start_supervised(
        {ThousandIsland,
         port: 0, handler_module: FailInitHandler, handler_options: :stop, num_acceptors: 1}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, _client} = :gen_tcp.connect(:localhost, port, [:binary, active: false], 1000)

    assert_receive {:telemetry, [:thousand_island, :acceptor, :spawn_error], measurements,
                    metadata},
                   1000

    assert measurements ~> %{monotonic_time: integer(), error: :intentional_init_failure}
    assert metadata ~> %{handler: FailInitHandler, telemetry_span_context: reference()}
  end
end
