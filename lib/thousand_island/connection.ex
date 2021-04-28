defmodule ThousandIsland.Connection do
  @moduledoc false

  def start(sup_pid, transport_socket, acceptor_id, %ThousandIsland.ServerConfig{
        transport_module: transport_module,
        handler_module: handler_module,
        handler_opts: handler_opts
      }) do
    connection_id = unique_id()

    # This is a multi-step process since we need to do a bit of work from within
    # the process which owns the socket (us, at this point).

    # Start by creating the worker process which will eventually handle this socket
    {:ok, pid} = DynamicSupervisor.start_child(sup_pid, {handler_module, handler_opts})

    # Since this process owns the socket at this point, it needs to be the
    # one to make this call. connection_pid is sitting and waiting for the
    # word from us to start processing, in order to ensure that we've made
    # the following call. Note that we purposefully do not match on the
    # return from this function; if there's an error the connection process
    # will see it, but it's no longer our problem if that's the case
    transport_module.controlling_process(transport_socket, pid)

    # Now that we have transferred ownership over to the new process, create a Socket
    # struct and send it to the new process via a message so it can start working
    # with the socket (note that the new process will still need to handshake with the remote end)
    socket =
      ThousandIsland.Socket.new(transport_socket, transport_module, connection_id, acceptor_id)

    Process.send(pid, {:thousand_island_ready, socket}, [])
  end

  defp unique_id, do: Base.encode16(:crypto.strong_rand_bytes(6))
end
