defmodule ThousandIsland.Connection do
  @moduledoc false

  @max_children_retries 5
  @max_children_retry_wait 1000

  def start(sup_pid, raw_socket, %ThousandIsland.ServerConfig{} = server_config, parent_span) do
    # This is a multi-step process since we need to do a bit of work from within
    # the process which owns the socket (us, at this point).

    # First, capture the start time for telemetry purposes
    start_time = ThousandIsland.Telemetry.monotonic_time()

    # Start by defining the worker process which will eventually handle this socket
    child_spec =
      {server_config.handler_module,
       {server_config.handler_options, server_config.genserver_options}}
      |> Supervisor.child_spec(shutdown: server_config.shutdown_timeout)

    # Then try to create it
    do_start(
      sup_pid,
      child_spec,
      raw_socket,
      server_config,
      parent_span,
      start_time,
      @max_children_retries
    )
  end

  defp do_start(sup_pid, child_spec, raw_socket, server_config, parent_span, start_time, retries) do
    case DynamicSupervisor.start_child(sup_pid, child_spec) do
      {:ok, pid} ->
        # Since this process owns the socket at this point, it needs to be the
        # one to make this call. connection_pid is sitting and waiting for the
        # word from us to start processing, in order to ensure that we've made
        # the following call. Note that we purposefully do not match on the
        # return from this function; if there's an error the connection process
        # will see it, but it's no longer our problem if that's the case
        server_config.transport_module.controlling_process(raw_socket, pid)

        # Now that we have transferred ownership over to the new process, send a message to the
        # new process with all the info it needs to start working with the socket (note that the
        # new process will still need to handshake with the remote end)
        Process.send(
          pid,
          {:thousand_island_ready, raw_socket, server_config, parent_span, start_time},
          []
        )

      {:error, :max_children} when retries > 0 ->
        # We're in a tricky spot here; we have a client connection in hand, but no room to put it
        # into the connection supervisor. We try to wait a maximum number of times to see if any
        # room opens up before we give up
        Process.sleep(@max_children_retry_wait)

        do_start(
          sup_pid,
          child_spec,
          raw_socket,
          server_config,
          parent_span,
          start_time,
          retries - 1
        )

      {:error, :max_children} ->
        # We gave up trying to find room for this connection in our supervisor.
        # Close the raw socket here and let the acceptor process handle propogating the error
        server_config.transport_module.close(raw_socket)
        {:error, :too_many_connections}

      other ->
        other
    end
  end
end
