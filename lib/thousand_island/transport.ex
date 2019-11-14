defmodule ThousandIsland.Transport do
  @type listener_socket() :: any()
  @type socket() :: any()
  @type socket_info() :: %{address: String.t(), port: non_neg_integer}
  @type way() :: :read | :write | :read_write
  @type on_recv() :: {:ok, binary()} | {:error, String.t()}

  @callback listen(keyword()) :: {:ok, listener_socket()}
  @callback accept(listener_socket()) :: {:ok, socket()}
  @callback recv(socket(), num_bytes :: non_neg_integer(), timeout :: timeout()) :: on_recv()
  @callback send(socket(), data :: binary()) :: :ok | {:error, String.t()}
  @callback shutdown(socket(), way()) :: :ok
  @callback close(socket() | listener_socket()) :: :ok
  @callback local_info(socket()) :: socket_info()
  @callback remote_info(socket()) :: socket_info()
end
