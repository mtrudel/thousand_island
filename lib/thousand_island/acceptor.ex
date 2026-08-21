defmodule ThousandIsland.Acceptor do
  @moduledoc false

  use Task, restart: :transient

  # Transient errors which accept(2) documents as retryable: on Linux, accept()
  # passes network errors already pending on the new socket back through the
  # accept call itself, and instructs applications to "treat them like EAGAIN
  # by retrying" (:etimedout is from the man page's adjacent list of errors
  # that various kernels can also return). These are conditions of a single
  # incoming connection, not of the listener, so we retry rather than crash
  # the acceptor. :econnaborted and :einval are the same kind of condition,
  # already handled in their own clause below with their own long-standing
  # telemetry events
  @transient_accept_errors [
    :enetdown,
    :enetunreach,
    :ehostdown,
    :ehostunreach,
    :enonet,
    :eproto,
    :enoprotoopt,
    :eopnotsupp,
    :etimedout
  ]

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

      {:error, {:spawn_error, reason}} ->
        # The socket was accepted fine but a handler process could not be
        # started for it (the socket has already been closed by
        # ThousandIsland.Connection). This is a failure of one connection, so
        # emit a spawn error and keep accepting rather than crashing the
        # acceptor
        ThousandIsland.Telemetry.span_event(span, :spawn_error, %{error: reason})

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

      {:error, reason} when reason in @transient_accept_errors ->
        # A transient error on the incoming connection which accept(2) tells us
        # to treat like EAGAIN. Emit an event for observability and keep
        # accepting rather than crashing the acceptor (and, through restart
        # escalation, the acceptor's supervisor and its live connections)
        ThousandIsland.Telemetry.span_event(span, :accept_error, %{error: reason})

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
