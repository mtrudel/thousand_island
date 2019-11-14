defmodule ThousandIsland.Handler do
  @callback handle_connection(ThousandIsland.Socket.t(), keyword()) :: :ok
end
