defmodule ThousandIsland.Logger do
  @moduledoc """
  Allows dynamically adding and altering the log level used to trace connections
  within a Thousand Island server via the use of telemetry hooks. Should you wish
  to do your own logging or tracking of these events, a complete list of the 
  telemetry events emitted by Thousand Island is described in the module 
  documentation for `ThousandIsland`. 
  """

  require Logger

  @doc """
  Start logging Thousand Island at the specified log level. Valid values for log 
  level are `:error`, `:info`, `:debug`, and `:trace`. Enabling a given log 
  level implicitly enables all higher log levels as well.
  """
  @spec attach_logger(atom()) :: :ok | {:error, :already_exists}
  def attach_logger(:error) do
    events = [
      [:connection, :handler, :exception],
      [:connection, :handler, :startup_timeout],
      [:connection, :handler, :handshake_error]
    ]

    :telemetry.attach_many("#{__MODULE__}.error", events, &log_error/4, nil)
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
      [:acceptor, :shutdown],
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
      [:socket, :sendfile, :complete],
      [:socket, :shutdown, :complete],
      [:socket, :close, :complete]
    ]

    :telemetry.attach_many("#{__MODULE__}.trace", events, &log_trace/4, nil)
  end

  @doc """
  Stop logging Thousand Island at the specified log level. Disabling a given log
  level implicitly disables all lower log levels as well.
  """
  @spec detach_logger(atom()) :: :ok | {:error, :not_found}
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

  @doc false
  def log_error([:connection, :handler, :exception], measurements, metadata, _config) do
    Logger.error(
      "Connection #{metadata.connection_id} handler #{metadata.server_config.handler_module} crashed with exception: #{
        measurements.formatted_exception
      }"
    )
  end

  def log_error([:connection, :handler, :handshake_error], measurements, metadata, _config) do
    Logger.error("Connection #{metadata.connection_id} handshake error #{measurements.reason}")
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
