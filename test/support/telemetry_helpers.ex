defmodule TelemetryHelpers do
  @moduledoc false

  @events [
    [:thousand_island, :listener, :start],
    [:thousand_island, :listener, :stop],
    [:thousand_island, :acceptor, :start],
    [:thousand_island, :acceptor, :stop],
    [:thousand_island, :acceptor, :spawn_error],
    [:thousand_island, :acceptor, :econnaborted],
    [:thousand_island, :connection, :start],
    [:thousand_island, :connection, :stop],
    [:thousand_island, :connection, :ready],
    [:thousand_island, :connection, :async_recv],
    [:thousand_island, :connection, :recv],
    [:thousand_island, :connection, :recv_error],
    [:thousand_island, :connection, :send],
    [:thousand_island, :connection, :send_error],
    [:thousand_island, :connection, :sendfile],
    [:thousand_island, :connection, :sendfile_error],
    [:thousand_island, :connection, :socket_shutdown]
  ]

  def attach_all_events(handler) do
    ref = make_ref()
    _ = :telemetry.attach_many(ref, @events, &__MODULE__.handle_event/4, {self(), handler})
    fn -> :telemetry.detach(ref) end
  end

  def handle_event(event, measurements, %{handler: handler} = metadata, {pid, handler}),
    do: send(pid, {:telemetry, event, measurements, metadata})

  def handle_event(_event, _measurements, _metadata, {_pid, _handler}), do: :ok
end
