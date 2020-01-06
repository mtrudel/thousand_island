defmodule ThousandIsland.Connection do
  @moduledoc false

  use Task

  alias ThousandIsland.ServerConfig

  @its_all_yours_timeout 5000

  def start(
        sup_pid,
        socket,
        acceptor_id,
        %ServerConfig{transport_module: transport_module} = server_config
      ) do
    # This is a multi-step process since we need to do a bit of work from within
    # the process which owns the socket. Start by creating the worker process
    # which will eventually handle this socket
    {:ok, pid} =
      DynamicSupervisor.start_child(sup_pid, {__MODULE__, {socket, acceptor_id, server_config}})

    # Since this process owns the socket at this point, it needs to be the
    # one to make this call. connection_pid is sitting and waiting for the
    # word from us to start processing, in order to ensure that we've made
    # the following call. Note that we purposefully do not match on the
    # return from this function; if there's an error the connection process
    # will see it, but it's no longer our problem if that's the case
    transport_module.controlling_process(socket, pid)

    # Now that we've given the socket over to the connection process, tell
    # it to start handling the connection
    Process.send(pid, :its_all_yours, [])
  end

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(
        {transport_socket, acceptor_id,
         %ServerConfig{
           transport_module: transport_module,
           handler_module: handler_module,
           handler_opts: handler_opts
         } = server_config}
      ) do
    Process.flag(:trap_exit, true)
    created = System.monotonic_time()

    connection_id = unique_id()

    connection_info = %{
      acceptor_id: acceptor_id,
      connection_id: connection_id,
      server_config: server_config
    }

    receive do
      :its_all_yours -> :ok
    after
      @its_all_yours_timeout ->
        telemetry(:startup_timeout, %{}, connection_info)
        raise "Did not receive :its_all_yours message within #{@its_all_yours_timeout}"
    end

    start = System.monotonic_time()
    telemetry(:start, %{}, connection_info)

    case transport_module.handshake(transport_socket) do
      {:ok, transport_socket} ->
        try do
          negotiated = System.monotonic_time()

          transport_socket
          |> ThousandIsland.Socket.new(connection_id, server_config)
          |> handler_module.handle_connection(handler_opts)

          measurements = %{
            duration: System.monotonic_time() - negotiated,
            handshake: negotiated - start,
            startup: start - created
          }

          telemetry(:complete, measurements, connection_info)
        rescue
          e ->
            formatted_exception = Exception.format(:error, e, __STACKTRACE__)

            telemetry(
              :exception,
              %{exception: e, formatted_exception: formatted_exception},
              connection_info
            )
        end

      {:error, reason} ->
        handshake = System.monotonic_time() - start
        telemetry(:handshake_error, %{handshake: handshake, reason: reason}, connection_info)
    end
  end

  defp telemetry(subevent, measurement, connection_info) do
    :telemetry.execute([:connection, :handler] ++ [subevent], measurement, connection_info)
  end

  defp unique_id, do: Base.encode16(:crypto.strong_rand_bytes(6))
end
