defmodule ThousandIsland.Logger do
  @moduledoc """
  Logging conveniences for Thousand Island servers

  Allows dynamically adding and altering the log level used to trace connections
  within a Thousand Island server via the use of telemetry hooks. Should you wish
  to do your own logging or tracking of these events, a complete list of the
  telemetry events emitted by Thousand Island is described in the module
  documentation for `ThousandIsland.Telemetry`.
  """

  require Logger

  @typedoc "Supported log levels"
  @type log_level :: :error | :info | :debug | :trace

  @doc """
  Start logging Thousand Island at the specified log level. Valid values for log
  level are `:error`, `:info`, `:debug`, and `:trace`. Enabling a given log
  level implicitly enables all higher log levels as well.
  """
  @spec attach_logger(log_level()) :: :ok | {:error, :already_exists}
  def attach_logger(:error) do
    events = [
      [:thousand_island, :acceptor, :spawn_error],
      [:thousand_island, :acceptor, :econnaborted]
    ]

    :telemetry.attach_many("#{__MODULE__}.error", events, &__MODULE__.log_error/4, nil)
  end

  def attach_logger(:info) do
    _ = attach_logger(:error)

    events = [
      [:thousand_island, :listener, :start],
      [:thousand_island, :listener, :stop]
    ]

    :telemetry.attach_many("#{__MODULE__}.info", events, &__MODULE__.log_info/4, nil)
  end

  def attach_logger(:debug) do
    _ = attach_logger(:info)

    events = [
      [:thousand_island, :acceptor, :start],
      [:thousand_island, :acceptor, :stop],
      [:thousand_island, :connection, :start],
      [:thousand_island, :connection, :stop]
    ]

    :telemetry.attach_many("#{__MODULE__}.debug", events, &__MODULE__.log_debug/4, nil)
  end

  def attach_logger(:trace) do
    _ = attach_logger(:debug)

    events = [
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

    :telemetry.attach_many("#{__MODULE__}.trace", events, &__MODULE__.log_trace/4, nil)
  end

  @doc """
  Stop logging Thousand Island at the specified log level. Disabling a given log
  level implicitly disables all lower log levels as well.
  """
  @spec detach_logger(log_level()) :: :ok | {:error, :not_found}
  def detach_logger(:error) do
    _ = detach_logger(:info)
    :telemetry.detach("#{__MODULE__}.error")
  end

  def detach_logger(:info) do
    _ = detach_logger(:debug)
    :telemetry.detach("#{__MODULE__}.info")
  end

  def detach_logger(:debug) do
    _ = detach_logger(:trace)
    :telemetry.detach("#{__MODULE__}.debug")
  end

  def detach_logger(:trace) do
    :telemetry.detach("#{__MODULE__}.trace")
  end

  @doc false
  @spec log_error(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: :ok
  def log_error(event, measurements, metadata, _config) do
    Logger.error(
      "#{inspect(event)} metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    )
  end

  @doc false
  @spec log_info(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: :ok
  def log_info(event, measurements, metadata, _config) do
    Logger.info(
      "#{inspect(event)} metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    )
  end

  @doc false
  @spec log_debug(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: :ok
  def log_debug(event, measurements, metadata, _config) do
    Logger.debug(
      "#{inspect(event)} metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    )
  end

  @doc false
  @spec log_trace(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :telemetry.handler_config()
        ) :: :ok
  def log_trace(event, measurements, metadata, _config) do
    Logger.debug(
      "#{inspect(event)} metadata: #{inspect(metadata)}, measurements: #{inspect(measurements)}"
    )
  end
end
