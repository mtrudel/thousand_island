defmodule ThousandIsland.ServerConfig do
  @moduledoc false

  @typedoc "A set of configuration parameters for a ThousandIsland server instance"
  @type t :: %__MODULE__{
          port: :inet.port_number(),
          transport_module: module(),
          transport_opts: ThousandIsland.transport_options(),
          handler_module: module(),
          handler_opts: term(),
          genserver_opts: GenServer.options(),
          num_acceptors: pos_integer()
        }

  defstruct [
    :port,
    :transport_module,
    :transport_opts,
    :handler_module,
    :handler_opts,
    :genserver_opts,
    :num_acceptors,
    :read_timeout
  ]

  @spec new(ThousandIsland.options()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      port: Keyword.get(opts, :port, 4000),
      transport_module: Keyword.get(opts, :transport_module, ThousandIsland.Transports.TCP),
      transport_opts: Keyword.get(opts, :transport_options, []),
      handler_module: Keyword.fetch!(opts, :handler_module),
      handler_opts: Keyword.get(opts, :handler_options, []),
      genserver_opts: Keyword.get(opts, :genserver_options, []),
      num_acceptors: Keyword.get(opts, :num_acceptors, 10),
      read_timeout: Keyword.get(opts, :read_timeout, :infinity)
    }
  end
end
