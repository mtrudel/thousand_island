defmodule ThousandIsland.TelemetryCollector do
  @moduledoc false

  use GenServer

  def start_link(event_types) do
    GenServer.start_link(__MODULE__, event_types)
  end

  def record_event(event, measurements, metadata, pid) do
    GenServer.cast(pid, {:event, event, measurements, metadata})
  end

  def get_events(pid) do
    GenServer.call(pid, :get_events)
  end

  def init(event_types) do
    # Use __MODULE__ here to keep telemetry from warning about passing a local capture
    # https://hexdocs.pm/telemetry/telemetry.html#attach/4
    :telemetry.attach_many(
      "#{inspect(self())}.trace",
      event_types,
      &__MODULE__.record_event/4,
      self()
    )

    {:ok, []}
  end

  def handle_cast({:event, event, measurements, metadata}, events) do
    {:noreply, [{event, measurements, metadata} | events]}
  end

  def handle_call(:get_events, _from, events) do
    {:reply, Enum.reverse(events), events}
  end
end
