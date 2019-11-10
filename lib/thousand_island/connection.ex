defmodule ThousandIsland.Connection do
  defstruct socket: nil, transport_module: nil

  def new(socket, opts) do
    transport_module = ThousandIsland.Transport.transport_module(opts)
    %__MODULE__{socket: socket, transport_module: transport_module}
  end

  def recv(%__MODULE__{socket: socket, transport_module: transport_module}, length \\ 0) do
    transport_module.recv(socket, length)
  end

  def send(%__MODULE__{socket: socket, transport_module: transport_module}, data) do
    transport_module.send(socket, data)
  end

  def close(%__MODULE__{socket: socket, transport_module: transport_module}) do
    transport_module.close(socket)
  end
end
