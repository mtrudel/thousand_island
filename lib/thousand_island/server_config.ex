defmodule ThousandIsland.ServerConfig do
  defstruct [
    :port,
    :transport_module,
    :transport_opts,
    :handler_module,
    :handler_opts,
    :num_acceptors
  ]

  def new(opts \\ []) do
    %__MODULE__{
      port: Keyword.get(opts, :port, 4000),
      transport_module: Keyword.get(opts, :transport_module, ThousandIsland.Transports.TCP),
      transport_opts: Keyword.get(opts, :transport_options, []),
      handler_module: Keyword.fetch!(opts, :handler_module),
      handler_opts: Keyword.get(opts, :handler_options, []),
      num_acceptors: Keyword.get(opts, :num_acceptors, 10)
    }
  end
end
