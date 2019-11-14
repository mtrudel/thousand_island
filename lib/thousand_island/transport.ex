defmodule ThousandIsland.Transport do
  @type listener_state() :: any()
  @type socket() :: any()
  @type endpoint() :: {ip :: String.t(), port :: non_neg_integer}
  @type way() :: :read | :write | :read_write

  @callback listen(keyword()) :: {:ok, listener_state()}
  @callback accept(listener_state()) :: {:ok, socket()}
  @callback recv(socket(), non_neg_integer()) :: {:ok, binary()} | {:error, String.t()}
  @callback send(socket(), binary()) :: :ok | {:error, String.t()}
  @callback shutdown(socket(), way()) :: :ok
  @callback close(socket()) :: :ok
  @callback endpoints(socket()) :: {local :: endpoint(), remote :: endpoint()}
end
