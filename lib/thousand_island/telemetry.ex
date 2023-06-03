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

  @typedoc false
  @type event_name ::
          :ready
          | :spawn_error
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

  @typedoc false
  @type stats :: %{
          required(:send_oct) => non_neg_integer(),
          required(:send_cnt) => non_neg_integer(),
          required(:recv_oct) => non_neg_integer(),
          required(:recv_cnt) => non_neg_integer()
        }

  @typedoc false
  @type measurements :: :telemetry.event_measurements()

  @type metadata :: :telemetry.event_metadata()

  @app_name :thousand_island

  @doc false
  @spec start_listener_span(
          ThousandIsland.Transport.address(),
          :inet.port_number(),
          ThousandIsland.transport_module(),
          ThousandIsland.transport_options()
        ) :: t()
  def start_listener_span(local_address, local_port, transport_module, transport_options),
    do:
      start_span(:listener, %{}, %{
        local_address: local_address,
        local_port: local_port,
        transport_module: transport_module,
        transport_options: transport_options
      })

  @doc false
  @spec start_acceptor_span(parent_span :: t()) :: t()
  def start_acceptor_span(parent_span), do: start_child_span(parent_span, :acceptor, %{}, %{})

  @doc false
  @spec start_connection_span(
          parent_span :: t(),
          integer(),
          ThousandIsland.Transport.address(),
          :inet.port_number()
        ) :: t()
  def start_connection_span(parent_span, monotonic_time, remote_address, remote_port),
    do:
      start_child_span(parent_span, :connection, %{monotonic_time: monotonic_time}, %{
        remote_address: remote_address,
        remote_port: remote_port
      })

  @doc false
  @spec stop_listener_span(t()) :: :ok
  def stop_listener_span(span), do: stop_span(span, %{}, %{})

  @doc false
  @spec stop_acceptor_span(t(), non_neg_integer(), reason) :: :ok
        when reason: nil | error,
             error: term()
  def stop_acceptor_span(span, connections, reason \\ nil)

  def stop_acceptor_span(span, connections, reason) when is_nil(reason),
    do: stop_span(span, %{connections: connections}, %{})

  def stop_acceptor_span(span, connections, reason),
    do: stop_span(span, %{connections: connections}, %{error: reason})

  @doc false
  @spec stop_connection_span(t(), stats(), reason) :: :ok
        when reason: :shutdown | :local_closed | error,
             error: term()
  def stop_connection_span(span, stats, reason) when reason in [:shutdown, :local_closed],
    do: stop_span(span, stats, %{})

  def stop_connection_span(span, stats, reason),
    do: stop_span(span, stats, %{error: reason})

  @doc false
  @spec stop_span_with_error(t(), reason :: any()) :: :ok
  def stop_span_with_error(span, reason), do: stop_span(span, %{}, %{error: reason})

  @spec start_span(span_name(), measurements(), metadata()) :: t()
  defp start_span(span_name, measurements, metadata) do
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

  @spec start_child_span(t(), span_name(), measurements(), metadata()) :: t()
  defp start_child_span(parent_span, span_name, measurements, metadata) do
    metadata =
      Map.put(metadata, :parent_telemetry_span_context, parent_span.telemetry_span_context)

    start_span(span_name, measurements, metadata)
  end

  @doc false
  @spec stop_span(t(), measurements(), metadata()) :: :ok
  defp stop_span(span, measurements, metadata) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)

    measurements =
      Map.put(measurements, :duration, measurements[:monotonic_time] - span.start_time)

    metadata = Map.merge(span.start_metadata, metadata)

    untimed_span_event(span, :stop, measurements, metadata)
  end

  @doc false
  @spec event_ready(t()) :: :ok
  def event_ready(span), do: span_event(span, :ready, %{}, %{})

  @doc false
  @spec event_spawn_error(t()) :: :ok
  def event_spawn_error(span), do: span_event(span, :spawn_error, %{}, %{})

  @doc false
  @spec event_recv_error(t(), reason :: term()) :: :ok
  def event_recv_error(span, reason), do: span_event(span, :recv_error, %{}, %{error: reason})

  @doc false
  @spec event_socket_shutdown(t(), ThousandIsland.Transport.way()) :: :ok
  def event_socket_shutdown(span, way), do: span_event(span, :socket_shutdown, %{way: way}, %{})

  @doc false
  @spec event_async_recv(t(), iodata()) :: :ok
  def event_async_recv(span, data), do: untimed_span_event(span, :async_recv, %{data: data}, %{})

  @doc false
  @spec event_recv(t(), iodata()) :: :ok
  def event_recv(span, data), do: untimed_span_event(span, :recv, %{data: data}, %{})

  @doc false
  @spec event_send(t(), iodata()) :: :ok
  def event_send(span, data), do: untimed_span_event(span, :send, %{data: data}, %{})

  @doc false
  @spec event_sendfile(t(), String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def event_sendfile(span, filename, offset, bytes_written),
    do:
      untimed_span_event(
        span,
        :sendfile,
        %{filename: filename, offset: offset, bytes_written: bytes_written},
        %{}
      )

  @doc false
  @spec event_send_error(t(), iodata(), reason :: term()) :: :ok
  def event_send_error(span, data, error),
    do: span_event(span, :send_error, %{data: data, error: error}, %{})

  @doc false
  @spec event_sendfile_error(
          t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          reason :: term()
        ) :: :ok
  def event_sendfile_error(span, filename, offset, length, reason),
    do:
      span_event(
        span,
        :sendfile_error,
        %{filename: filename, offset: offset, length: length, error: reason},
        %{}
      )

  @doc false
  @spec span_event(t(), event_name(), measurements(), metadata()) :: :ok
  defp span_event(span, name, measurements, metadata) do
    measurements = Map.put_new_lazy(measurements, :monotonic_time, &monotonic_time/0)
    untimed_span_event(span, name, measurements, metadata)
  end

  @doc false
  @spec untimed_span_event(t(), event_name() | untimed_event_name(), measurements(), metadata()) ::
          :ok
  defp untimed_span_event(span, name, measurements, metadata) do
    metadata = Map.put(metadata, :telemetry_span_context, span.telemetry_span_context)
    event([span.span_name, name], measurements, metadata)
  end

  @doc false
  @spec monotonic_time() :: integer
  defdelegate monotonic_time, to: System

  @spec event(:telemetry.event_name(), measurements(), metadata()) :: :ok
  defp event(suffix, measurements, metadata) do
    :telemetry.execute([@app_name | suffix], measurements, metadata)
  end
end
