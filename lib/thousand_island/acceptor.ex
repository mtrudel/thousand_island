defmodule ThousandIsland.Acceptor do
  @moduledoc false

  use Task, restart: :transient

  @spec start_link(
          {server :: Supervisor.supervisor(), parent :: Supervisor.supervisor(),
           ThousandIsland.ServerConfig.t()}
        ) :: {:ok, pid()}
  def start_link(arg), do: Task.start_link(__MODULE__, :run, [arg])

  @spec run(
          {server :: Supervisor.supervisor(), parent :: Supervisor.supervisor(),
           ThousandIsland.ServerConfig.t()}
        ) :: no_return
  def run({server_pid, parent_pid, %ThousandIsland.ServerConfig{} = server_config}) do
    listener_pid = ThousandIsland.Server.listener_pid(server_pid)
    {listener_socket, listener_span} = ThousandIsland.Listener.acceptor_info(listener_pid)
    connection_sup_pid = ThousandIsland.AcceptorSupervisor.connection_sup_pid(parent_pid)
    acceptor_span = ThousandIsland.Telemetry.start_acceptor_span(listener_span)
    accept(listener_socket, connection_sup_pid, server_config, acceptor_span, 0)
  end

  defp accept(listener_socket, connection_sup_pid, server_config, span, count) do
    with {:ok, socket} <- server_config.transport_module.accept(listener_socket),
         :ok <- ThousandIsland.Connection.start(connection_sup_pid, socket, server_config, span) do
      accept(listener_socket, connection_sup_pid, server_config, span, count + 1)
    else
      {:error, :too_many_connections} ->
        ThousandIsland.Telemetry.event_spawn_error(span)

      {:error, reason} when reason in [:closed, :einval] ->
        ThousandIsland.Telemetry.stop_acceptor_span(span, _connections = count)

      {:error, reason} ->
        ThousandIsland.Telemetry.stop_acceptor_span(span, _connections = count, reason)

        raise "Unexpected error in accept: #{inspect(reason)}"
    end
  end
end
