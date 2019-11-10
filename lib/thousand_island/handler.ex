defmodule ThousandIsland.Handler do
  @callback handle_connection(ThousandIsland.Connection.t()) :: :ok

  def handler_module(opts) do
    Keyword.get(opts, :handler_module)
  end
end
