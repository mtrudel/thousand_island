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
          num_acceptors: pos_integer(),
          read_timeout: timeout(),
          parent_span_id: String.t()
        }

  defstruct [
    :port,
    :transport_module,
    :transport_opts,
    :handler_module,
    :handler_opts,
    :genserver_opts,
    :num_acceptors,
    :read_timeout,
    :parent_span_id
  ]

  @spec new(ThousandIsland.options()) :: t()
  def new(opts \\ []) do
    if !:proplists.is_defined(:handler_module, opts),
      do: raise("No handler_module defined in server configuration")

    %__MODULE__{
      port: :proplists.get_value(:port, opts, 4000),
      transport_module:
        :proplists.get_value(:transport_module, opts, ThousandIsland.Transports.TCP),
      transport_opts: :proplists.get_value(:transport_options, opts, []),
      handler_module: :proplists.get_value(:handler_module, opts),
      handler_opts: :proplists.get_value(:handler_options, opts, []),
      genserver_opts: :proplists.get_value(:genserver_options, opts, []),
      num_acceptors: :proplists.get_value(:num_acceptors, opts, 10),
      read_timeout: :proplists.get_value(:read_timeout, opts, :infinity),
      parent_span_id: :proplists.get_value(:parent_span_id, opts)
    }
  end
end
