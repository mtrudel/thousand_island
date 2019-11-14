defmodule ThousandIsland.Socket do
  defstruct socket: nil, transport_module: nil
  @type t :: %__MODULE__{socket: ThousandIsland.Transport.socket(), transport_module: module()}

  def new(socket, transport_module) do
    %__MODULE__{socket: socket, transport_module: transport_module}
  end

  def recv(
        %__MODULE__{socket: socket, transport_module: transport_module},
        length \\ 0,
        timeout \\ :infinity
      ) do
    transport_module.recv(socket, length, timeout)
  end

  def send(%__MODULE__{socket: socket, transport_module: transport_module}, data) do
    transport_module.send(socket, data)
  end

  def shutdown(%__MODULE__{socket: socket, transport_module: transport_module}, way) do
    transport_module.shutdown(socket, way)
  end

  def close(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.close(socket)
  end

  def local_info(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.local_info(socket)
  end

  def remote_info(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.remote_info(socket)
  end
end
