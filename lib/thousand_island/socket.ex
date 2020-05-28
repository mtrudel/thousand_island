defmodule ThousandIsland.Socket do
  @moduledoc """
  Encapsulates a client connection's underlying socket, providing a facility to
  read, write, and otherwise manipulate a connection from a client. 
  `ThousandIsland.Socket` instances are passed to the application layer of a server
  via the `c:ThousandIsland.Handler.handle_connection/2` callback. 
  """

  defstruct socket: nil, transport_module: nil, connection_id: nil

  alias ThousandIsland.{ServerConfig, Transport}

  @typedoc "A reference to a socket along with metadata describing how to use it"
  @opaque t :: %__MODULE__{
            socket: Transport.socket(),
            transport_module: module(),
            connection_id: String.t()
          }

  @doc false
  @spec new(Transport.socket(), String.t(), ServerConfig.t()) :: t()
  def new(socket, connection_id, %ServerConfig{transport_module: transport_module}) do
    %__MODULE__{socket: socket, transport_module: transport_module, connection_id: connection_id}
  end

  @doc """
  Returns available bytes on the given socket. Up to `num_bytes` bytes will be
  returned (0 can be passed in to get the next 'available' bytes, typically the 
  next packet). If insufficient bytes are available, the functino can wait `timeout` 
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

    :telemetry.execute([:socket, :recv, :complete], %{result: result}, %{
      connection_id: connection_id
    })

    result
  end

  @doc """
  Sends the given data (specified as a binary or an IO list) on the given socket.
  """
  @spec send(t(), IO.iodata()) :: :ok | {:error, term()}
  def send(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        data
      ) do
    result = transport_module.send(socket, data)

    :telemetry.execute([:socket, :send, :complete], %{result: result, data: data}, %{
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
      [:socket, :sendfile, :complete],
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
  @spec setopts(t(), Transport.socket_opts()) :: :ok | {:error, String.t()}
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
    :telemetry.execute([:socket, :shutdown, :complete], %{}, %{connection_id: connection_id})
    result
  end

  @doc """
  Closes the given socket.
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{
        socket: socket,
        transport_module: transport_module,
        connection_id: connection_id
      }) do
    result = transport_module.close(socket)
    :telemetry.execute([:socket, :close, :complete], %{}, %{connection_id: connection_id})
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
end
