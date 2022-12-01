defmodule Telemetrex.App do
  @moduledoc """
  Encapsulates the telemetry spans and events which may be emitted by an application
  """

  defstruct app_name: nil, spans: []

  def new(definition) do
    definition
    |> then(&struct!(__MODULE__, &1))
    |> Map.update!(:spans, fn spans -> Enum.map(spans, &Telemetrex.Span.new/1) end)
  end
end
