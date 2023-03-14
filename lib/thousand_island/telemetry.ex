defmodule ThousandIsland.Telemetry do
  @moduledoc """
  The following telemetry spans are emitted by thousand_island

  ## `[:thousand_island, :listener, *]`

  Represents a Thousand Island server listening to a port

  This span is started by the following event:

  * `[:thousand_island, :listener, :start]`

      Represents the start of the span

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `span_id`: The ID of this span
      * `parent_id`: The span ID passed to Thousand Island via the `parent_span_id` option
      * `local_address`: The IP address that the listener is bound to
      * `local_port`: The port that the listener is bound to
      * `transport_module`: The transport module in use
      * `transport_options`: Options passed to the transport module at startup


  This span is ended by the following event:

  * `[:thousand_island, :listener, :stop]`

      Represents the end of the span

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units
      * `duration`: The span duration, in `:native` units

      This event contains the following metadata:

      * `span_id`: The ID of this span

  ## `[:thousand_island, :acceptor, *]`

  Represents a Thousand Island acceptor process listening for connections

  This span is started by the following event:

  * `[:thousand_island, :acceptor, :start]`

      Represents the start of the span

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `span_id`: The ID of this span
      * `parent_id`: The span ID of the `:listener` which created this acceptor

  This span is ended by the following event:

  * `[:thousand_island, :acceptor, :stop]`

      Represents the end of the span

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units
      * `duration`: The span duration, in `:native` units
      * `connections`: The number of client requests that the acceptor handled

      This event contains the following metadata:

      * `span_id`: The ID of this span
      * `error`: The error that caused the span to end, if it ended in error

  ## `[:thousand_island, :connection, *]`

  Represents Thousand Island handling a specific client request

  This span is started by the following event:

  * `[:thousand_island, :connection, :start]`

      Represents the start of the span

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `span_id`: The ID of this span
      * `parent_id`: The span ID of the `:acceptor` span which accepted this connection
      * `remote_address`: The IP address of the connected client
      * `remote_port`: The port of the connected client

  This span is ended by the following event:

  * `[:thousand_island, :connection, :stop]`

      Represents the end of the span

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units
      * `duration`: The span duration, in `:native` units
      * `send_oct`: The number of octets sent on the connection
      * `send_cnt`: The number of packets sent on the connection
      * `recv_oct`: The number of octets received on the connection
      * `recv_cnt`: The number of packets received on the connection

      This event contains the following metadata:

      * `span_id`: The ID of this span
      * `error`: The error that caused the span to end, if it ended in error

  The following events may be emitted within this span:

  * `[:thousand_island, :connection, :ready]`

      Thousand Island has completed setting up the client connection

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :async_recv]`

      Thousand Island has asynchronously received data from the client

      This event contains the following measurements:

      * `data`: The data received from the client

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :recv]`

      Thousand Island has synchronously received data from the client

      This event contains the following measurements:

      * `data`: The data received from the client

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :recv_error]`

      Thousand Island encountered an error reading data from the client

      This event contains the following measurements:

      * `error`: A description of the error

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :send]`

      Thousand Island has sent data to the client

      This event contains the following measurements:

      * `data`: The data sent to the client

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :send_error]`

      Thousand Island encountered an error sending data to the client

      This event contains the following measurements:

      * `data`: The data that was being sent to the client
      * `error`: A description of the error

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :sendfile]`

      Thousand Island has sent a file to the client

      This event contains the following measurements:

      * `filename`: The filename containing data sent to the client
      * `offset`: The offset (in bytes) within the file sending started from
      * `bytes_written`: The number of bytes written

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :sendfile_error]`

      Thousand Island encountered an error sending a file to the client

      This event contains the following measurements:

      * `filename`: The filename containing data that was being sent to the client
      * `offset`: The offset (in bytes) within the file where sending started from
      * `length`: The number of bytes that were attempted to send
      * `error`: A description of the error

      This event contains the following metadata:

      * `span_id`: The ID of this span

  * `[:thousand_island, :connection, :socket_shutdown]`

      Thousand Island has shutdown the client connection

      This event contains the following measurements:

      * `time`: The time of this event, in `:native` units
      * `way`: The direction in which the socket was shut down

      This event contains the following metadata:

      * `span_id`: The ID of this span
  """

  defstruct span_name: nil, span_id: nil, start_time: nil

  @type t :: %__MODULE__{
          span_name: atom(),
          span_id: String.t(),
          start_time: integer()
        }

  @app_name :thousand_island

  @doc false
  @spec start_span(atom(), map(), map()) :: t()
  def start_span(span_name, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :time, &time/0)
    span_id = random_identifier()
    metadata = Map.put(metadata, :span_id, span_id)
    event([span_name, :start], measurements, metadata)
    %__MODULE__{span_name: span_name, span_id: span_id, start_time: measurements[:time]}
  end

  @doc false
  @spec start_child_span(t(), atom(), map(), map()) :: t()
  def start_child_span(parent_span, span_name, measurements \\ %{}, metadata \\ %{}) do
    metadata = Map.put(metadata, :parent_id, parent_span.span_id)
    start_span(span_name, measurements, metadata)
  end

  @doc false
  @spec stop_span(t(), map(), map()) :: :ok
  def stop_span(span, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :time, &time/0)
    measurements = Map.put(measurements, :duration, measurements[:time] - span.start_time)
    untimed_span_event(span, :stop, measurements, metadata)
  end

  @doc false
  @spec span_event(t(), atom(), map(), map()) :: :ok
  def span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    measurements = Map.put_new_lazy(measurements, :time, &time/0)
    untimed_span_event(span, name, measurements, metadata)
  end

  @doc false
  @spec untimed_span_event(t(), atom(), map(), map()) :: :ok
  def untimed_span_event(span, name, measurements \\ %{}, metadata \\ %{}) do
    metadata = Map.put(metadata, :span_id, span.span_id)
    event([span.span_name, name], measurements, metadata)
  end

  defdelegate time, to: System, as: :monotonic_time

  defp event(suffix, measurements, metadata) do
    :telemetry.execute([@app_name | suffix], measurements, metadata)
  end

  # XXX Drop this once we drop support for OTP 23
  @compile {:inline, random_identifier: 0}
  if function_exported?(:rand, :bytes, 1) do
    defp random_identifier, do: Base.encode32(:rand.bytes(10), padding: false)
  else
    defp random_identifier, do: Base.encode32(:crypto.strong_rand_bytes(10), padding: false)
  end
end
