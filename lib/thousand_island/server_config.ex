defmodule ThousandIsland.ServerConfig do
  @moduledoc """
  Encapsulates the configuration of a ThousandIsland server instance

  This is used internally by `ThousandIsland.Handler`
  """

  @typedoc "A set of configuration parameters for a ThousandIsland server instance"
  @type t :: %__MODULE__{
          port: :inet.port_number(),
          transport_module: ThousandIsland.transport_module(),
          transport_options: ThousandIsland.transport_options(),
          handler_module: module(),
          handler_options: term(),
          genserver_options: GenServer.options(),
          supervisor_options: [Supervisor.option()],
          num_acceptors: pos_integer(),
          num_listen_sockets: pos_integer(),
          num_connections: non_neg_integer() | :infinity,
          max_connections_retry_count: non_neg_integer(),
          max_connections_retry_wait: timeout(),
          read_timeout: timeout(),
          shutdown_timeout: timeout(),
          silent_terminate_on_error: boolean()
        }

  defstruct port: 4000,
            transport_module: ThousandIsland.Transports.TCP,
            transport_options: [],
            handler_module: nil,
            handler_options: [],
            genserver_options: [],
            supervisor_options: [],
            num_acceptors: 100,
            num_listen_sockets: 1,
            num_connections: 16_384,
            max_connections_retry_count: 5,
            max_connections_retry_wait: 1000,
            read_timeout: 60_000,
            shutdown_timeout: 15_000,
            silent_terminate_on_error: false

  @spec new(ThousandIsland.options()) :: t()
  def new(opts \\ []) do
    if !:proplists.is_defined(:handler_module, opts),
      do: raise("No handler_module defined in server configuration")

    config = struct!(__MODULE__, opts)

    if config.num_listen_sockets > config.num_acceptors do
      raise(
        "num_listen_sockets (#{config.num_listen_sockets}) must be less than or equal to num_acceptors (#{config.num_acceptors})"
      )
    end

    config
  end
end
