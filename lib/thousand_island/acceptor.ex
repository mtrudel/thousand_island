defmodule ThousandIsland.Acceptor do
  @moduledoc false

  use Task, restart: :transient

  # How long to pause the accept loop when the system reports file descriptor
  # exhaustion (:emfile / :enfile). We cannot accept while out of descriptors, so
  # we back off briefly to let the situation resolve rather than spinning or
  # crashing. This mirrors Ranch's behaviour (ranch_acceptor.erl).
  @fd_exhaustion_wait 100

  @spec start_link(
          {server :: Supervisor.supervisor(), parent :: Supervisor.supervisor(), pos_integer(),
           ThousandIsland.ServerConfig.t()}
        ) :: {:ok, pid()}
  def start_link(arg), do: Task.start_link(__MODULE__, :run, [arg])

  @spec run(
          {server :: Supervisor.supervisor(), parent :: Supervisor.supervisor(), pos_integer(),
           ThousandIsland.ServerConfig.t()}
        ) :: no_return
  def run({server_pid, parent_pid, acceptor_id, %ThousandIsland.ServerConfig{} = server_config}) do
    ThousandIsland.ProcessLabel.set(:acceptor, server_config, acceptor_id)

    listener_pid = ThousandIsland.Server.listener_pid(server_pid)

    {listener_socket, listener_span} =
      ThousandIsland.Listener.acceptor_info(listener_pid, acceptor_id)

    connection_sup_pid = ThousandIsland.AcceptorSupervisor.connection_sup_pid(parent_pid)
    acceptor_span = ThousandIsland.Telemetry.start_child_span(listener_span, :acceptor)

    # Pre-create the handler config once to avoid Map.take on every connection (hot path)
    handler_config = ThousandIsland.HandlerConfig.from_server_config(server_config)

    accept(listener_socket, connection_sup_pid, server_config, handler_config, acceptor_span, 0)
  end

  defp accept(listener_socket, connection_sup_pid, server_config, handler_config, span, count) do
    with {:ok, socket} <- server_config.transport_module.accept(listener_socket),
         :ok <-
           ThousandIsland.Connection.start(
             connection_sup_pid,
             socket,
             server_config,
             handler_config,
             span
           ) do
      accept(listener_socket, connection_sup_pid, server_config, handler_config, span, count + 1)
    else
      {:error, :too_many_connections} ->
        ThousandIsland.Telemetry.span_event(span, :spawn_error)

        accept(
          listener_socket,
          connection_sup_pid,
          server_config,
          handler_config,
          span,
          count + 1
        )

      {:error, reason} when reason in [:econnaborted, :einval] ->
        ThousandIsland.Telemetry.span_event(span, reason)

        accept(
          listener_socket,
          connection_sup_pid,
          server_config,
          handler_config,
          span,
          count + 1
        )

      {:error, reason} when reason in [:emfile, :enfile] ->
        # File descriptors are exhausted, so nothing can be accepted right now.
        # Back off briefly to let the situation resolve rather than crashing the
        # acceptor (whose crash loop would escalate through the supervision
        # tree, killing in-flight connections along the way). This mirrors
        # Ranch's handling of the same condition
        ThousandIsland.Telemetry.span_event(span, :emfile, %{error: reason})
        Process.sleep(@fd_exhaustion_wait)

        accept(
          listener_socket,
          connection_sup_pid,
          server_config,
          handler_config,
          span,
          count + 1
        )

      {:error, :closed} ->
        ThousandIsland.Telemetry.stop_span(span, %{connections: count})

      {:error, reason} ->
        ThousandIsland.Telemetry.stop_span(span, %{connections: count}, %{error: reason})
        raise "Unexpected error in accept: #{inspect(reason)}"
    end
  end
end
