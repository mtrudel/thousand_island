defmodule ThousandIsland.Acceptor do
  use Task, restart: :transient

  alias ThousandIsland.{
    Listener,
    Server,
    ServerConfig,
    AcceptorSupervisor,
    Connection,
    ConnectionSupervisor
  }

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run({server_pid, parent_pid, %ServerConfig{} = config}) do
    listener_pid = Server.listener_pid(server_pid)
    {:ok, listener_socket} = Listener.listener_socket(listener_pid)

    acceptor_info = %{
      acceptor_id: UUID.uuid4(),
      listener_socket: listener_socket,
      connection_sup_pid: AcceptorSupervisor.connection_sup_pid(parent_pid),
      server_config: config
    }

    telemetry(:start, %{}, acceptor_info)
    accept(acceptor_info)
  end

  defp accept(
         %{
           listener_socket: listener_socket,
           connection_sup_pid: connection_sup_pid,
           server_config: %ServerConfig{transport_module: transport_module} = server_config
         } = acceptor_info
       ) do
    start = System.monotonic_time()

    case transport_module.accept(listener_socket) do
      {:ok, socket} ->
        wakeup = System.monotonic_time()

        {:ok, connection_pid} =
          ConnectionSupervisor.start_connection(
            connection_sup_pid,
            {socket, server_config}
          )

        # Since this process owns the socket at this point, it needs to be the
        # one to make this call. connection_pid is sitting and waiting for the
        # word from us to start processing, in order to ensure that we've made
        # the following call. Note that we purposefully do not match on the 
        # return from this function; if there's an error the connection process
        # will see it, but it's no longer our problem if that's the case
        transport_module.controlling_process(socket, connection_pid)

        # Now that we've given the socket over to the connection process, tell 
        # it to start handling the connection
        Connection.start_processing(connection_pid)

        complete = System.monotonic_time()
        wait_time = wakeup - start
        startup_time = complete - wakeup
        telemetry(:accept, %{wait_time: wait_time, startup_time: startup_time}, acceptor_info)
        accept(acceptor_info)

      {:error, reason} ->
        wakeup = System.monotonic_time()
        wait_time = wakeup - start
        telemetry(:shutdown, %{wait_time: wait_time, shutdown_reason: reason}, acceptor_info)

        # Reasons other than closed are unexpected, so raise up and let our supervisor take care of things
        if !(reason in [:closed]) do
          raise "Unexpected error in accept: #{inspect(reason)}"
        end
    end
  end

  defp telemetry(subevent, measurement, acceptor_info) do
    acceptor_info = Map.take(acceptor_info, [:acceptor_id, :server_config])
    :telemetry.execute([:acceptor] ++ [subevent], measurement, acceptor_info)
  end
end
