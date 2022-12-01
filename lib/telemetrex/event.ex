defmodule Telemetrex.Event do
  @moduledoc """
  Encapsulates the details of a telemetry event definition
  """

  defstruct name: nil,
            description: nil,
            metadata: [],
            measurements: []

  def new(definition, event_type \\ :span_event) do
    {untimed, definition} = Keyword.pop(definition, :untimed, false)

    definition
    |> then(&struct!(__MODULE__, &1))
    |> Map.merge(default_fields(event_type))
    |> Map.update!(:metadata, &Keyword.merge(default_metadata(event_type), &1))
    |> Map.update!(:metadata, &Keyword.merge(default_metadata(), &1))
    |> Map.update!(:measurements, &Keyword.merge(default_measurements(event_type), &1))
    |> Map.update!(:measurements, &Keyword.merge(default_measurements(untimed), &1))
  end

  defp default_fields(:start_event),
    do: %{name: :start, description: "Represents the start of the span"}

  defp default_fields(:stop_event),
    do: %{name: :stop, description: "Represents the end of the span"}

  defp default_fields(:exception_event),
    do: %{name: :exception, description: "Represents an exception that occurred within the span"}

  defp default_fields(:span_event), do: %{}

  defp default_metadata(:start_event), do: [parent_id: "The ID of this span's parent"]
  defp default_metadata(:stop_event), do: []
  defp default_metadata(:exception_event), do: []
  defp default_metadata(:span_event), do: []
  defp default_metadata, do: [span_id: "The ID of this span"]

  defp default_measurements(:start_event), do: []

  defp default_measurements(:stop_event),
    do: [
      duration: "The span duration, in `:native` units",
      error: "The error that caused the span to end, if it ended in error"
    ]

  defp default_measurements(:exception_event), do: []
  defp default_measurements(:span_event), do: []
  defp default_measurements(true), do: []
  defp default_measurements(false), do: [time: "The time of this event, in `:native` units"]
end
