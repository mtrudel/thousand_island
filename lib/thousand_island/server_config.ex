defmodule ThousandIsland.ServerConfig do
  @moduledoc false

  @typedoc "A set of configuration parameters for a ThousandIsland server instance"
  @type t :: %__MODULE__{
          port: :inet.port_number(),
          transport_module: module(),
          transport_opts: keyword(),
          handler_module: module(),
          handler_opts: term(),
          num_acceptors: pos_integer()
        }

  @typedoc "Valid options when creating a ServerConfig struct"
  @type options() :: [
          port: :inet.port_number(),
          transport_module: module(),
          transport_opts: keyword(),
          handler_module: module(),
          handler_opts: keyword(),
          num_acceptors: pos_integer()
        ]

  defstruct [
    :port,
    :transport_module,
    :transport_opts,
    :handler_module,
    :handler_opts,
    :num_acceptors
  ]

  @spec new(options()) :: t()
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
