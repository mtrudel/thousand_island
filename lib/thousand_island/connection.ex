defmodule ThousandIsland.Connection do
  @moduledoc false

  def start(sup_pid, raw_socket, %ThousandIsland.ServerConfig{} = server_config, parent_span) do
    # This is a multi-step process since we need to do a bit of work from within
    # the process which owns the socket (us, at this point).

    # Start the span to represent the connection. We do this here (in the acceptor process) so
    # that we can see the effect of the handler process startup & socket transfer
    peer_info = server_config.transport_module.peer_info(raw_socket)
    span_meta = %{remote_address: peer_info.address, remote_port: peer_info.port}
    span = ThousandIsland.Telemetry.start_child_span(parent_span, :connection, %{}, span_meta)

    # Start by creating the worker process which will eventually handle this socket
    child_spec =
      {server_config.handler_module,
       {server_config.handler_options, server_config.genserver_options}}

    {:ok, pid} = DynamicSupervisor.start_child(sup_pid, child_spec)

    # Since this process owns the socket at this point, it needs to be the
    # one to make this call. connection_pid is sitting and waiting for the
    # word from us to start processing, in order to ensure that we've made
    # the following call. Note that we purposefully do not match on the
    # return from this function; if there's an error the connection process
    # will see it, but it's no longer our problem if that's the case
    server_config.transport_module.controlling_process(raw_socket, pid)

    # Now that we have transferred ownership over to the new process, create a Socket
    # struct and send it to the new process via a message so it can start working
    # with the socket (note that the new process will still need to handshake with the remote end)
    socket = ThousandIsland.Socket.new(raw_socket, server_config, span)
    Process.send(pid, {:thousand_island_ready, socket}, [])
  end
end
