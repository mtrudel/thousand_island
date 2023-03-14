defmodule ThousandIsland.ServerConfig do
  @moduledoc false

  @typedoc "A set of configuration parameters for a ThousandIsland server instance"
  @type t :: %__MODULE__{
          port: :inet.port_number(),
          transport_module: module(),
          transport_options: ThousandIsland.transport_options(),
          handler_module: module(),
          handler_options: term(),
          genserver_options: GenServer.options(),
          num_acceptors: pos_integer(),
          read_timeout: timeout(),
          shutdown_timeout: timeout(),
          parent_span_id: String.t() | nil
        }

  defstruct port: 4000,
            transport_module: ThousandIsland.Transports.TCP,
            transport_options: [],
            handler_module: nil,
            handler_options: [],
            genserver_options: [],
            num_acceptors: 100,
            read_timeout: 60_000,
            shutdown_timeout: 15_000,
            parent_span_id: nil

  @spec new(ThousandIsland.options()) :: t()
  def new(opts \\ []) do
    if !:proplists.is_defined(:handler_module, opts),
      do: raise("No handler_module defined in server configuration")

    struct!(__MODULE__, opts)
  end
end
