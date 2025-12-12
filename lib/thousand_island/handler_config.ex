defmodule ThousandIsland.HandlerConfig do
  @moduledoc """
  A minimal config struct containing only the fields needed by connection handlers.

  This is used internally by `ThousandIsland.Handler`
  """

  @enforce_keys [:handler_module, :transport_module, :read_timeout, :silent_terminate_on_error]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          handler_module: nil,
          transport_module: module(),
          read_timeout: timeout(),
          silent_terminate_on_error: boolean()
        }

  @doc """
  Creates a HandlerConfig from a ServerConfig, extracting only the fields needed
  by connection handlers. This should be called once per acceptor at initialization.
  """
  @spec from_server_config(ThousandIsland.ServerConfig.t()) :: t()
  def from_server_config(%ThousandIsland.ServerConfig{} = config) do
    %__MODULE__{
      handler_module: config.handler_module,
      transport_module: config.transport_module,
      read_timeout: config.read_timeout,
      silent_terminate_on_error: config.silent_terminate_on_error
    }
  end
end
