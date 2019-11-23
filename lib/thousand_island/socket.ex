defmodule ThousandIsland.Socket do
  defstruct socket: nil, transport_module: nil, connection_id: nil

  @type uuid :: String.t()

  @type t :: %__MODULE__{
          socket: ThousandIsland.Transport.socket(),
          transport_module: module(),
          connection_id: uuid()
        }

  def new(socket, %{transport_module: transport_module, connection_id: connection_id}) do
    %__MODULE__{socket: socket, transport_module: transport_module, connection_id: connection_id}
  end

  def recv(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        length \\ 0,
        timeout \\ :infinity
      ) do
    start = System.monotonic_time()
    result = transport_module.recv(socket, length, timeout)
    duration = System.monotonic_time() - start

    :telemetry.execute([:socket, :recv, :complete], %{duration: duration, result: result}, %{
      connection_id: connection_id
    })

    result
  end

  def send(
        %__MODULE__{
          socket: socket,
          transport_module: transport_module,
          connection_id: connection_id
        },
        data
      ) do
    start = System.monotonic_time()
    result = transport_module.send(socket, data)
    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:socket, :send, :complete],
      %{duration: duration, result: result, data: data},
      %{
        connection_id: connection_id
      }
    )

    result
  end

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

  def close(%__MODULE__{
        socket: socket,
        transport_module: transport_module,
        connection_id: connection_id
      }) do
    result = transport_module.close(socket)
    :telemetry.execute([:socket, :close, :complete], %{}, %{connection_id: connection_id})
    result
  end

  def local_info(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.local_info(socket)
  end

  def peer_info(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.peer_info(socket)
  end
end
