defmodule ThousandIsland.Transport do
  @type listener_socket() :: any()
  @type socket() :: any()
  @type socket_info() :: %{address: String.t(), port: :inet.port_number()}
  @type way() :: :read | :write | :read_write
  @type on_recv() :: {:ok, binary()} | {:error, String.t()}

  @callback listen(:inet.port_number(), keyword()) :: {:ok, listener_socket()}
  @callback listen_port(listener_socket()) :: {:ok, :inet.port_number()}
  @callback accept(listener_socket()) :: {:ok, socket()}
  @callback handshake(socket()) :: {:ok, socket()} | {:error, any()}
  @callback recv(socket(), num_bytes :: non_neg_integer(), timeout :: timeout()) :: on_recv()
  @callback send(socket(), data :: binary()) :: :ok | {:error, String.t()}
  @callback shutdown(socket(), way()) :: :ok
  @callback close(socket() | listener_socket()) :: :ok
  @callback local_info(socket()) :: socket_info()
  @callback peer_info(socket()) :: socket_info()
end
