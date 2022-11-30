defmodule ThousandIsland.Acceptor do
  @moduledoc false

  use Task, restart: :transient

  def start_link(arg), do: Task.start_link(__MODULE__, :run, [arg])

  def run({server_pid, parent_pid, %ThousandIsland.ServerConfig{} = server_config}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    listener_socket = ThousandIsland.Listener.acceptor_info(listener_pid)
    connection_sup_pid = ThousandIsland.AcceptorSupervisor.connection_sup_pid(parent_pid)
    accept(listener_socket, connection_sup_pid, server_config)
  end

  defp accept(listener_socket, connection_sup_pid, server_config) do
    case server_config.transport_module.accept(listener_socket) do
      {:ok, socket} ->
        ThousandIsland.Connection.start(connection_sup_pid, socket, server_config)
        accept(listener_socket, connection_sup_pid, server_config)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        raise "Unexpected error in accept: #{inspect(reason)}"
    end
  end
end
