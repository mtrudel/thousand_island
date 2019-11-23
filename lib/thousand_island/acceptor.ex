defmodule ThousandIsland.Acceptor do
  use Task, restart: :transient

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run({server_pid, parent_pid, opts}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {:ok, listener_socket} = ThousandIsland.Listener.listener_socket(listener_pid)

    acceptor_info = %{
      acceptor_id: UUID.uuid4(),
      listener_socket: listener_socket,
      transport_module: Keyword.get(opts, :transport_module, ThousandIsland.Transports.TCP),
      handler_module: Keyword.get(opts, :handler_module),
      handler_opts: Keyword.get(opts, :handler_options, []),
      connection_sup_pid: ThousandIsland.AcceptorSupervisor.connection_sup_pid(parent_pid)
    }

    telemetry(:start, %{}, acceptor_info)
    accept(acceptor_info)
  end

  defp accept(acceptor_info) do
    start = System.monotonic_time()

    case acceptor_info.transport_module.accept(acceptor_info.listener_socket) do
      {:ok, socket} ->
        awoke = System.monotonic_time()

        ThousandIsland.ConnectionSupervisor.start_connection(
          acceptor_info.connection_sup_pid,
          {socket, acceptor_info.transport_module, acceptor_info.handler_module,
           acceptor_info.handler_opts}
        )

        complete = System.monotonic_time()
        wait_time = awoke - start
        startup_time = complete - awoke
        telemetry(:accept, %{wait_time: wait_time, startup_time: startup_time}, acceptor_info)
        accept(acceptor_info)

      {:error, reason} ->
        awoke = System.monotonic_time()
        wait_time = awoke - start
        telemetry(:shutdown, %{wait_time: wait_time, shutdown_reason: reason}, acceptor_info)
    end
  end

  defp telemetry(subevent, measurement, acceptor_info) do
    acceptor_info = Map.take(acceptor_info, [:acceptor_id, :handler_module, :handler_opts])
    :telemetry.execute([:acceptor] ++ [subevent], measurement, acceptor_info)
  end
end
