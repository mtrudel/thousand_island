defmodule ThousandIsland.Handler do
  @callback handle_connection(ThousandIsland.Socket.t(), keyword()) :: :ok

  def handler_module(opts) do
    Keyword.fetch!(opts, :handler_module)
  end

  def handler_opts(opts) do
    Keyword.get(opts, :handler_opts, [])
  end
end
