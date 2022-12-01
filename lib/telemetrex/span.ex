defmodule Telemetrex.Span do
  @moduledoc """
  Encapsulates the details of a telemetry span definition
  """

  defstruct name: nil,
            description: nil,
            start_event: [],
            stop_event: [],
            exception_event: [],
            extra_events: []

  def new(definition) do
    definition
    |> then(&struct!(__MODULE__, &1))
    |> Map.update!(:start_event, &Telemetrex.Event.new(&1, :start_event))
    |> Map.update!(:stop_event, &Telemetrex.Event.new(&1, :stop_event))
    |> Map.update!(:exception_event, &Telemetrex.Event.new(&1, :exception_event))
    |> Map.update!(:extra_events, fn events -> Enum.map(events, &Telemetrex.Event.new/1) end)
  end
end
