defmodule ThousandIsland.Acceptor do
  use Task, restart: :transient

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run({server_pid, parent_pid, opts}) do
    acceptor_id = UUID.uuid4()
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {:ok, listener_socket} = ThousandIsland.Listener.listener_socket(listener_pid)
    transport_module = Keyword.get(opts, :transport_module, ThousandIsland.Transports.TCP)
    handler_module = Keyword.get(opts, :handler_module)
    handler_opts = Keyword.get(opts, :handler_options, [])
    connection_sup_pid = ThousandIsland.AcceptorSupervisor.connection_sup_pid(parent_pid)

    :telemetry.execute([:acceptor, :start], %{}, %{
      acceptor_id: acceptor_id,
      handler_module: handler_module,
      handler_opts: handler_opts
    })

    accept(listener_socket, transport_module, handler_module, handler_opts, connection_sup_pid, acceptor_id)
  end

  defp accept(listener_socket, transport_module, handler_module, handler_opts, connection_sup_pid, acceptor_id) do
    start = System.monotonic_time()

    case transport_module.accept(listener_socket) do
      {:ok, socket} ->
        awoke = System.monotonic_time()

        ThousandIsland.ConnectionSupervisor.start_connection(
          connection_sup_pid,
          {socket, transport_module, handler_module, handler_opts}
        )

        complete = System.monotonic_time()

        wait_time = awoke - start
        startup_time = complete - awoke

        :telemetry.execute([:acceptor, :accept], %{wait_time: wait_time, startup_time: startup_time}, %{
          acceptor_id: acceptor_id,
          handler_module: handler_module,
          handler_opts: handler_opts
        })

        accept(listener_socket, transport_module, handler_module, handler_opts, connection_sup_pid, acceptor_id)

      {:error, reason} ->
        awoke = System.monotonic_time()
        wait_time = awoke - start

        :telemetry.execute([:acceptor, :complete], %{wait_time: wait_time, shutdown_reason: reason}, %{
          acceptor_id: acceptor_id,
          handler_module: handler_module,
          handler_opts: handler_opts
        })
    end
  end
end
