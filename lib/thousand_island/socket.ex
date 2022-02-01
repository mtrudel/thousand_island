defmodule ThousandIsland.Socket do
  @moduledoc """
  Encapsulates a client connection's underlying socket, providing a facility to
  read, write, and otherwise manipulate a connection from a client.
  """

  defstruct socket: nil, transport_module: nil, connection_id: nil, acceptor_id: nil

  alias ThousandIsland.Transport

  @typedoc "A reference to a socket along with metadata describing how to use it"
  @type t :: %__MODULE__{
          socket: Transport.socket(),
          transport_module: module(),
          connection_id: String.t(),
          acceptor_id: String.t()
        }

  @doc false
  @spec new(Transport.socket(), module(), String.t(), String.t()) :: t()
  def new(socket, transport_module, connection_id, acceptor_id) do
    %__MODULE__{
      socket: socket,
      transport_module: transport_module,
      connection_id: connection_id,
      acceptor_id: acceptor_id
    }
  end

  @doc """
  Handshakes the underlying socket if it is required (as in the case of SSL sockets, for example).
  """
  @spec handshake(t()) :: {:ok, t()} | {:error, String.t()}
  def handshake(
        %__MODULE__{
          socket: transport_socket,
          transport_module: transport_module,
          connection_id: connection_id
        } = socket
      ) do
    case transport_module.handshake(transport_socket) do
      {:ok, _} ->
        :telemetry.execute([:socket, :handshake], %{}, %{connection_id: connection_id})
        {:ok, socket}

      {:error, error} ->
        :telemetry.execute([:socket, :handshake_error], %{error: error}, %{
          connection_id: connection_id
        })

        {:error, error}
    end
  end

  @doc """
  Returns available bytes on the given socket. Up to `num_bytes` bytes will be
  returned (0 can be passed in to get the next 'available' bytes, typically the
  next packet). If insufficient bytes are available, the function can wait `timeout`
  milliseconds for data to arrive.
  """
  @spec recv(t(), non_neg_integer(), timeout()) :: Transport.on_recv()
  def recv(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        length \\ 0,
        timeout \\ :infinity
      ) do
    result = transport_module.recv(socket, length, timeout)

    :telemetry.execute([:socket, :recv], %{result: result}, %{
      connection_id: connection_id
    })

    result
  end

  @doc """
  Sends the given data (specified as a binary or an IO list) on the given socket.
  """
  @spec send(t(), IO.chardata()) :: :ok | {:error, term()}
  def send(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        data
      ) do
    result = transport_module.send(socket, data)

    :telemetry.execute([:socket, :send], %{result: result, data: data}, %{
      connection_id: connection_id
    })

    result
  end

  @doc """
  Sends the contents of the given file based on the provided offset & length
  """
  @spec sendfile(t(), String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def sendfile(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        filename,
        offset,
        length
      ) do
    result = transport_module.sendfile(socket, filename, offset, length)

    :telemetry.execute(
      [:socket, :sendfile],
      %{
        result: result,
        file: filename,
        offset: offset,
        length: length
      },
      %{
        connection_id: connection_id
      }
    )

    result
  end

  @doc """
  Sets the given flags on the socket
  """
  @spec setopts(t(), Transport.socket_options()) :: :ok | {:error, String.t()}
  def setopts(%__MODULE__{socket: socket, transport_module: transport_module}, options) do
    transport_module.setopts(socket, options)
  end

  @doc """
  Shuts down the socket in the given direction.
  """
  @spec shutdown(t(), Transport.way()) :: :ok
  def shutdown(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        way
      ) do
    result = transport_module.shutdown(socket, way)
    :telemetry.execute([:socket, :shutdown], %{}, %{connection_id: connection_id})
    result
  end

  @doc """
  Closes the given socket. Note that a socket is automatically closed when the handler
  process which owns it terminates
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{
        socket: socket,
        transport_module: transport_module,
        connection_id: connection_id
      }) do
    stats =
      case transport_module.getstat(socket) do
        {:ok, stats} -> stats
        _ -> %{}
      end

    measurements = %{
      octets_sent: stats[:send_oct],
      packets_sent: stats[:send_cnt],
      octets_recv: stats[:recv_oct],
      packets_recv: stats[:recv_cnt]
    }

    result = transport_module.close(socket)

    :telemetry.execute([:socket, :close], measurements, %{connection_id: connection_id})
    result
  end

  @doc """
  Returns information in the form of `t:ThousandIsland.Transport.socket_info()` about the local end of the socket.
  """
  @spec local_info(t()) :: Transport.socket_info()
  def local_info(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.local_info(socket)
  end

  @doc """
  Returns information in the form of `t:ThousandIsland.Transport.socket_info()` about the remote end of the socket.
  """
  @spec peer_info(t()) :: Transport.socket_info()
  def peer_info(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.peer_info(socket)
  end

  @doc """
  Returns whether or not this protocol is secure.
  """
  @spec secure?(t()) :: boolean()
  def secure?(%__MODULE__{transport_module: transport_module}) do
    transport_module.secure?()
  end

  @doc """
  Returns information about the protocol negotiated during transport handshaking (if any).
  """
  @spec negotiated_protocol(t()) :: Transport.negotiated_protocol_info()
  def negotiated_protocol(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.negotiated_protocol(socket)
  end
end
