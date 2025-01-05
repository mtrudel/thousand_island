defmodule ThousandIsland.Telemetry do
  @moduledoc """
  The following telemetry spans are emitted by thousand_island

  ## `[:thousand_island, :listener, *]`

  Represents a Thousand Island server listening to a port

  This span is started by the following event:

  * `[:thousand_island, :listener, :start]`

      Represents the start of the span

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
      * `local_address`: The IP address that the listener is bound to
      * `local_port`: The port that the listener is bound to
      * `transport_module`: The transport module in use
      * `transport_options`: Options passed to the transport module at startup


  This span is ended by the following event:

  * `[:thousand_island, :listener, :stop]`

      Represents the end of the span

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units
      * `duration`: The span duration, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
      * `local_address`: The IP address that the listener is bound to
      * `local_port`: The port that the listener is bound to
      * `transport_module`: The transport module in use
      * `transport_options`: Options passed to the transport module at startup

  ## `[:thousand_island, :acceptor, *]`

  Represents a Thousand Island acceptor process listening for connections

  This span is started by the following event:

  * `[:thousand_island, :acceptor, :start]`

      Represents the start of the span

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
      * `parent_telemetry_span_context`: The span context of the `:listener` which created this acceptor

  This span is ended by the following event:

  * `[:thousand_island, :acceptor, :stop]`

      Represents the end of the span

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units
      * `duration`: The span duration, in `:native` units
      * `connections`: The number of client requests that the acceptor handled

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
      * `parent_telemetry_span_context`: The span context of the `:listener` which created this acceptor
      * `error`: The error that caused the span to end, if it ended in error

  The following events may be emitted within this span:

  * `[:thousand_island, :acceptor, :spawn_error]`

      Thousand Island was unable to spawn a process to handle a connection. This occurs when too
      many connections are in progress; you may want to look at increasing the `num_connections`
      configuration parameter

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :acceptor, :econnaborted]`

      Thousand Island was unable to spawn a process to handle a connection since the remote end
      closed before we could accept it. This usually occurs when it takes too long for your server
      to start processing a connection; you may want to look at tuning OS-level TCP parameters or
      adding more server capacity.

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  ## `[:thousand_island, :connection, *]`

  Represents Thousand Island handling a specific client request

  This span is started by the following event:

  * `[:thousand_island, :connection, :start]`

      Represents the start of the span

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
      * `parent_telemetry_span_context`: The span context of the `:acceptor` span which accepted
      this connection
      * `remote_address`: The IP address of the connected client
      * `remote_port`: The port of the connected client

  This span is ended by the following event:

  * `[:thousand_island, :connection, :stop]`

      Represents the end of the span

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units
      * `duration`: The span duration, in `:native` units
      * `send_oct`: The number of octets sent on the connection
      * `send_cnt`: The number of packets sent on the connection
      * `recv_oct`: The number of octets received on the connection
      * `recv_cnt`: The number of packets received on the connection

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
      * `parent_telemetry_span_context`: The span context of the `:acceptor` span which accepted
        this connection
      * `remote_address`: The IP address of the connected client
      * `remote_port`: The port of the connected client
      * `error`: The error that caused the span to end, if it ended in error

  The following events may be emitted within this span:

  * `[:thousand_island, :connection, :ready]`

      Thousand Island has completed setting up the client connection

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :async_recv]`

      Thousand Island has asynchronously received data from the client

      This event contains the following measurements:

      * `data`: The data received from the client

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :recv]`

      Thousand Island has synchronously received data from the client

      This event contains the following measurements:

      * `data`: The data received from the client

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :recv_error]`

      Thousand Island encountered an error reading data from the client

      This event contains the following measurements:

      * `error`: A description of the error

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :send]`

      Thousand Island has sent data to the client

      This event contains the following measurements:

      * `data`: The data sent to the client

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :send_error]`

      Thousand Island encountered an error sending data to the client

      This event contains the following measurements:

      * `data`: The data that was being sent to the client
      * `error`: A description of the error

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :sendfile]`

      Thousand Island has sent a file to the client

      This event contains the following measurements:

      * `filename`: The filename containing data sent to the client
      * `offset`: The offset (in bytes) within the file sending started from
      * `bytes_written`: The number of bytes written

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :sendfile_error]`

      Thousand Island encountered an error sending a file to the client

      This event contains the following measurements:

      * `filename`: The filename containing data that was being sent to the client
      * `offset`: The offset (in bytes) within the file where sending started from
      * `length`: The number of bytes that were attempted to send
      * `error`: A description of the error

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span

  * `[:thousand_island, :connection, :socket_shutdown]`

      Thousand Island has shutdown the client connection

      This event contains the following measurements:

      * `monotonic_time`: The time of this event, in `:native` units
      * `way`: The direction in which the socket was shut down

      This event contains the following metadata:

      * `telemetry_span_context`: A unique identifier for this span
  """

  @enforce_keys [:span_name, :telemetry_span_context, :start_time, :start_metadata]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          span_name: span_name(),
          telemetry_span_context: reference(),
          start_time: integer(),
          start_metadata: metadata()
        }

  @type span_name :: :listener | :acceptor | :connection
  @type metadata :: :telemetry.event_metadata()

  @typedoc false
  @type measurements :: :telemetry.event_measurements()

  @typedoc false
  @type event_name ::
          :ready
          | :spawn_error
          | :econnaborted
          | :recv_error
          | :send_error
          | :sendfile_error
          | :socket_shutdown

  @typedoc false
  @type untimed_event_name ::
          :async_recv
          | :stop
          | :recv
          | :send
          | :sendfile

  @app_name :thousand_island

  @doc false
  @spec start_span(span_name(), measurements(), metadata()) :: t()
  def start_span(span_name, measurements, metadata) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)
    telemetry_span_context = make_ref()
    metadata = Map.put(metadata, :telemetry_span_context, telemetry_span_context)
    _ = event([span_name, :start], measurements, metadata)

    %__MODULE__{
      span_name: span_name,
      telemetry_span_context: telemetry_span_context,
      start_time: measurements[:monotonic_time],
      start_metadata: metadata
    }
  end

  @doc false
  @spec start_child_span(t(), span_name(), measurements(), metadata()) :: t()
  def start_child_span(parent_span, span_name, measurements \\ %{}, metadata \\ %{}) do
    metadata =
      metadata
      |> Map.put(:parent_telemetry_span_context, parent_span.telemetry_span_context)
      |> Map.put(:handler, parent_span.start_metadata.handler)

    start_span(span_name, measurements, metadata)
  end

  @doc false
  @spec stop_span(t(), measurements(), metadata()) :: :ok
  def stop_span(span, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)

    measurements =
      Map.put(measurements, :duration, measurements[:monotonic_time] - span.start_time)

    metadata = Map.merge(span.start_metadata, metadata)

    untimed_span_event(span, :stop, measurements, metadata)
  end

  @doc false
  @spec span_event(t(), event_name(), measurements(), metadata()) :: :ok
  def span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)
    untimed_span_event(span, name, measurements, metadata)
  end

  @doc false
  @spec untimed_span_event(t(), event_name() | untimed_event_name(), measurements(), metadata()) ::
          :ok
  def untimed_span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    metadata =
      metadata
      |> Map.put(:telemetry_span_context, span.telemetry_span_context)
      |> Map.put(:handler, span.start_metadata.handler)

    event([span.span_name, name], measurements, metadata)
  end

  @spec monotonic_time() :: integer
  defdelegate monotonic_time, to: System

  defp event(suffix, measurements, metadata) do
    :telemetry.execute([@app_name | suffix], measurements, metadata)
  end
end
