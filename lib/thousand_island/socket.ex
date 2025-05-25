defmodule ThousandIsland.Socket do
  @moduledoc """
  Encapsulates a client connection's underlying socket, providing a facility to
  read, write, and otherwise manipulate a connection from a client.
  """

  @enforce_keys [:socket, :transport_module, :read_timeout, :silent_terminate_on_error, :span]
  defstruct @enforce_keys

  @typedoc "A reference to a socket along with metadata describing how to use it"
  @type t :: %__MODULE__{
          socket: ThousandIsland.Transport.socket(),
          transport_module: module(),
          read_timeout: timeout(),
          silent_terminate_on_error: boolean(),
          span: ThousandIsland.Telemetry.t()
        }

  @doc """
  Creates a new socket struct based on the passed parameters.

  This is normally called internally by `ThousandIsland.Handler` and does not need to be
  called by implementations which are based on `ThousandIsland.Handler`
  """
  @spec new(
          ThousandIsland.Transport.socket(),
          ThousandIsland.ServerConfig.t(),
          ThousandIsland.Telemetry.t()
        ) :: t()
  def new(raw_socket, server_config, span) do
    %__MODULE__{
      socket: raw_socket,
      transport_module: server_config.transport_module,
      read_timeout: server_config.read_timeout,
      silent_terminate_on_error: server_config.silent_terminate_on_error,
      span: span
    }
  end

  @doc """
  Handshakes the underlying socket if it is required (as in the case of SSL sockets, for example).

  This is normally called internally by `ThousandIsland.Handler` and does not need to be
  called by implementations which are based on `ThousandIsland.Handler`
  """
  @spec handshake(t()) :: ThousandIsland.Transport.on_handshake()
  def handshake(%__MODULE__{} = socket) do
    case socket.transport_module.handshake(socket.socket) do
      {:ok, inner_socket} ->
        {:ok, %{socket | socket: inner_socket}}

      {:error, reason} = err ->
        ThousandIsland.Telemetry.stop_span(socket.span, %{}, %{error: reason})
        err
    end
  end

  @doc """
  Upgrades the transport of the socket to use the specified transport module, performing any client
  handshaking that may be required. The passed options are blindly passed through to the new
  transport module.

  This is normally called internally by `ThousandIsland.Handler` and does not need to be
  called by implementations which are based on `ThousandIsland.Handler`
  """
  @spec upgrade(t(), module(), term()) :: ThousandIsland.Transport.on_upgrade()
  def upgrade(%__MODULE__{} = socket, module, opts) when is_atom(module) do
    case module.upgrade(socket.socket, opts) do
      {:ok, updated_socket} ->
        {:ok, %__MODULE__{socket | socket: updated_socket, transport_module: module}}

      {:error, reason} = err ->
        ThousandIsland.Telemetry.stop_span(socket.span, %{}, %{error: reason})
        err
    end
  end

  @doc """
  Returns available bytes on the given socket. Up to `length` bytes will be
  returned (0 can be passed in to get the next 'available' bytes, typically the
  next packet). If insufficient bytes are available, the function can wait `timeout`
  milliseconds for data to arrive.
  """
  @spec recv(t(), non_neg_integer(), timeout() | nil) :: ThousandIsland.Transport.on_recv()
  def recv(%__MODULE__{} = socket, length \\ 0, timeout \\ nil) do
    case socket.transport_module.recv(socket.socket, length, timeout || socket.read_timeout) do
      {:ok, data} = ok ->
        ThousandIsland.Telemetry.untimed_span_event(socket.span, :recv, %{data: data})
        ok

      {:error, reason} = err ->
        ThousandIsland.Telemetry.span_event(socket.span, :recv_error, %{error: reason})
        err
    end
  end

  @doc """
  Sends the given data (specified as a binary or an IO list) on the given socket.
  """
  @spec send(t(), iodata()) :: ThousandIsland.Transport.on_send()
  def send(%__MODULE__{} = socket, data) do
    case socket.transport_module.send(socket.socket, data) do
      :ok ->
        ThousandIsland.Telemetry.untimed_span_event(socket.span, :send, %{data: data})
        :ok

      {:error, reason} = err ->
        ThousandIsland.Telemetry.span_event(socket.span, :send_error, %{data: data, error: reason})

        err
    end
  end

  @doc """
  Sends the contents of the given file based on the provided offset & length
  """
  @spec sendfile(t(), String.t(), non_neg_integer(), non_neg_integer()) ::
          ThousandIsland.Transport.on_sendfile()
  def sendfile(%__MODULE__{} = socket, filename, offset, length) do
    case socket.transport_module.sendfile(socket.socket, filename, offset, length) do
      {:ok, bytes_written} = ok ->
        measurements = %{filename: filename, offset: offset, bytes_written: bytes_written}
        ThousandIsland.Telemetry.untimed_span_event(socket.span, :sendfile, measurements)
        ok

      {:error, reason} = err ->
        measurements = %{filename: filename, offset: offset, length: length, error: reason}
        ThousandIsland.Telemetry.span_event(socket.span, :sendfile_error, measurements)
        err
    end
  end

  @doc """
  Shuts down the socket in the given direction.
  """
  @spec shutdown(t(), ThousandIsland.Transport.way()) :: ThousandIsland.Transport.on_shutdown()
  def shutdown(%__MODULE__{} = socket, way) do
    ThousandIsland.Telemetry.span_event(socket.span, :socket_shutdown, %{way: way})
    socket.transport_module.shutdown(socket.socket, way)
  end

  @doc """
  Closes the given socket. Note that a socket is automatically closed when the handler
  process which owns it terminates
  """
  @spec close(t()) :: ThousandIsland.Transport.on_close()
  def close(%__MODULE__{} = socket) do
    socket.transport_module.close(socket.socket)
  end

  @doc """
  Gets the given flags on the socket

  Errors are usually from :inet.posix(), however, SSL module defines return type as any()
  """
  @spec getopts(t(), ThousandIsland.Transport.socket_get_options()) ::
          ThousandIsland.Transport.on_getopts()
  def getopts(%__MODULE__{} = socket, options) do
    socket.transport_module.getopts(socket.socket, options)
  end

  @doc """
  Sets the given flags on the socket

  Errors are usually from :inet.posix(), however, SSL module defines return type as any()
  """
  @spec setopts(t(), ThousandIsland.Transport.socket_set_options()) ::
          ThousandIsland.Transport.on_setopts()
  def setopts(%__MODULE__{} = socket, options) do
    socket.transport_module.setopts(socket.socket, options)
  end

  @doc """
  Returns information in the form of `t:ThousandIsland.Transport.socket_info()` about the local end of the socket.
  """
  @spec sockname(t()) :: ThousandIsland.Transport.on_sockname()
  def sockname(%__MODULE__{} = socket) do
    socket.transport_module.sockname(socket.socket)
  end

  @doc """
  Returns information in the form of `t:ThousandIsland.Transport.socket_info()` about the remote end of the socket.
  """
  @spec peername(t()) :: ThousandIsland.Transport.on_peername()
  def peername(%__MODULE__{} = socket) do
    socket.transport_module.peername(socket.socket)
  end

  @doc """
  Returns information in the form of `t:public_key.der_encoded()` about the peer certificate of the socket.
  """
  @spec peercert(t()) :: ThousandIsland.Transport.on_peercert()
  def peercert(%__MODULE__{} = socket) do
    socket.transport_module.peercert(socket.socket)
  end

  @doc """
  Returns whether or not this protocol is secure.
  """
  @spec secure?(t()) :: boolean()
  def secure?(%__MODULE__{} = socket) do
    socket.transport_module.secure?()
  end

  @doc """
  Returns statistics about the connection.
  """
  @spec getstat(t()) :: ThousandIsland.Transport.socket_stats()
  def getstat(%__MODULE__{} = socket) do
    socket.transport_module.getstat(socket.socket)
  end

  @doc """
  Returns information about the protocol negotiated during transport handshaking (if any).
  """
  @spec negotiated_protocol(t()) :: ThousandIsland.Transport.on_negotiated_protocol()
  def negotiated_protocol(%__MODULE__{} = socket) do
    socket.transport_module.negotiated_protocol(socket.socket)
  end

  @doc """
  Returns information about the SSL connection info, if transport is SSL.
  """
  @spec connection_information(t()) :: ThousandIsland.Transport.on_connection_information()
  def connection_information(%__MODULE__{} = socket) do
    socket.transport_module.connection_information(socket.socket)
  end

  @doc """
  Returns the telemetry span representing the lifetime of this socket
  """
  @spec telemetry_span(t()) :: ThousandIsland.Telemetry.t()
  def telemetry_span(%__MODULE__{} = socket) do
    socket.span
  end
end
