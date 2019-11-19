defmodule ThousandIsland.AcceptorWorker do
  use Task, restart: :transient

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run({server_pid, parent_pid, opts}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {:ok, listener_socket} = ThousandIsland.Listener.listener_socket(listener_pid)
    transport_module = Keyword.get(opts, :transport_module, ThousandIsland.Transports.TCP)
    handler_module = Keyword.get(opts, :handler_module)
    handler_opts = Keyword.get(opts, :handler_options, [])
    connection_sup_pid = ThousandIsland.Acceptor.connection_sup_pid(parent_pid)

    accept(listener_socket, transport_module, handler_module, handler_opts, connection_sup_pid)
  end

  defp accept(listener_socket, transport_module, handler_module, handler_opts, connection_sup_pid) do
    {:ok, socket} = transport_module.accept(listener_socket)

    ThousandIsland.ConnectionSupervisor.start_connection(
      connection_sup_pid,
      {socket, transport_module, handler_module, handler_opts}
    )

    accept(listener_socket, transport_module, handler_module, handler_opts, connection_sup_pid)
  end
end
