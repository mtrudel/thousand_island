defmodule ThousandIsland.Logger do
  require Logger

  def attach_logger(:error) do
    :telemetry.attach(
      "#{__MODULE__}.error",
      [:connection, :handler, :exception],
      &log_error/4,
      nil
    )
  end

  def attach_logger(:info) do
    attach_logger(:error)
    :telemetry.attach("#{__MODULE__}.info", [:transport, :listen, :start], &log_info/4, nil)
  end

  def attach_logger(:debug) do
    attach_logger(:info)

    events = [
      [:transport, :listen, :start],
      [:acceptor, :start],
      [:acceptor, :accept],
      [:connection, :handler, :start],
      [:connection, :handler, :complete]
    ]

    :telemetry.attach_many("#{__MODULE__}.debug", events, &log_debug/4, nil)
  end

  def attach_logger(:trace) do
    attach_logger(:debug)

    events = [
      [:listener, :start],
      [:socket, :recv, :complete],
      [:socket, :send, :complete],
      [:socket, :shutdown, :complete],
      [:socket, :close, :complete]
    ]

    :telemetry.attach_many("#{__MODULE__}.trace", events, &log_trace/4, nil)
  end

  def detach_logger(:error) do
    detach_logger(:info)
    :telemetry.detach("#{__MODULE__}.error")
  end

  def detach_logger(:info) do
    detach_logger(:debug)
    :telemetry.detach("#{__MODULE__}.info")
  end

  def detach_logger(:debug) do
    detach_logger(:trace)
    :telemetry.detach("#{__MODULE__}.debug")
  end

  def detach_logger(:trace) do
    :telemetry.detach("#{__MODULE__}.trace")
  end

  def log_error([:connection, :handler, :exception], measurements, metadata, _config) do
    str = Exception.format(:error, measurements.exception, measurements.stacktrace)

    Logger.error(
      "Connection #{metadata.connection_id} handler #{metadata.handler_module} crashed with exception: #{
        str
      }"
    )
  end

  def log_info([:transport, :listen, :start], measurements, _metadata, _config) do
    Logger.info("Transport #{measurements.transport} listening on port #{measurements.port}")
  end

  def log_debug(event, measurements, metadata, _config) do
    Logger.debug(
      "#{inspect(event)} metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    )
  end

  def log_trace(event, measurements, metadata, _config) do
    Logger.debug(
      "#{inspect(event)} metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    )
  end
end
