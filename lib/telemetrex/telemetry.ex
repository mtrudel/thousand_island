defmodule Telemetrex.Telemetry do
  @moduledoc """
  TODO
  """

  defmacro __using__(app_name: app_name) do
    quote do
      # TODO inline
      @doc false
      def start_span(span_name, measurements, metadata) do
        Telemetrex.Telemetry.start_span(unquote(app_name), span_name, measurements, metadata)
      end

      # TODO inline
      @doc false
      def start_child_span(parent_span, span_name, measurements \\ %{}, metadata \\ %{}) do
        Telemetrex.Telemetry.start_child_span(parent_span, span_name, measurements, metadata)
      end

      # TODO inline
      @doc false
      def stop_span(span, measurements \\ %{}, metadata \\ %{}) do
        Telemetrex.Telemetry.stop_span(span, measurements, metadata)
      end

      # TODO inline
      @doc false
      def span_event(span, event_name, measurements \\ %{}, metadata \\ %{}) do
        Telemetrex.Telemetry.span_event(span, event_name, measurements, metadata)
      end

      # TODO inline
      @doc false
      def untimed_span_event(span, event_name, measurements \\ %{}, metadata \\ %{}) do
        Telemetrex.Telemetry.untimed_span_event(span, event_name, measurements, metadata)
      end
    end
  end

  defstruct app_name: nil, span_name: nil, span_id: nil, start_time: nil

  @type t :: %__MODULE__{
          app_name: atom(),
          span_name: atom(),
          span_id: String.t(),
          start_time: integer()
        }

  @spec start_span(atom(), atom(), map(), map()) :: t()
  def start_span(app_name, span_name, measurements \\ %{}, metadata \\ %{}) do
    time = System.monotonic_time()
    measurements = Map.put(measurements, :time, time)
    span_id = Base.encode32(:rand.bytes(10), padding: false)
    metadata = Map.put(metadata, :span_id, span_id)
    event([app_name, span_name, :start], measurements, metadata)
    %__MODULE__{app_name: app_name, span_name: span_name, span_id: span_id, start_time: time}
  end

  @spec start_child_span(t(), atom(), map(), map()) :: t()
  def start_child_span(parent_span, span_name, measurements \\ %{}, metadata \\ %{}) do
    metadata = Map.put(metadata, :parent_id, parent_span.span_id)
    start_span(parent_span.app_name, span_name, measurements, metadata)
  end

  @spec stop_span(t(), map(), map()) :: :ok
  def stop_span(span, measurements \\ %{}, metadata \\ %{}) do
    time = System.monotonic_time()

    measurements =
      measurements
      |> Map.put(:time, time)
      |> Map.put(:duration, time - span.start_time)

    untimed_span_event(span, :stop, measurements, metadata)
  end

  @spec span_event(t(), atom(), map(), map()) :: :ok
  def span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    time = System.monotonic_time()
    measurements = Map.put(measurements, :time, time)
    untimed_span_event(span, name, measurements, metadata)
  end

  @spec untimed_span_event(t(), atom(), map(), map()) :: :ok
  def untimed_span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    metadata = Map.put(metadata, :span_id, span.span_id)
    event([span.app_name, span.span_name, name], measurements, metadata)
  end

  defp event(event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
  end
end
