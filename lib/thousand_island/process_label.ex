defmodule ThousandIsland.ProcessLabel do
  @moduledoc false
  # Provides compile-time conditional support for Process.set_label/1
  # which was introduced in Elixir 1.17.0 and OTP 27.
  @supports_labels Version.match?(System.version(), ">= 1.17.0") and
                     String.to_integer(System.otp_release()) >= 27

  @type config() :: ThousandIsland.ServerConfig.t() | ThousandIsland.HandlerConfig.t()

  if @supports_labels do
    @doc """
    Sets a process label if the current Elixir version supports it (>= 1.17).
    """
    @spec set(atom(), config(), term()) ::
            :ok
    def set(name, %ThousandIsland.ServerConfig{} = config, state) when is_atom(name) do
      Process.set_label({:thousand_island, name, {{config.port, config.handler_module}, state}})
    end

    def set(name, %ThousandIsland.HandlerConfig{} = config, state) when is_atom(name) do
      Process.set_label({:thousand_island, name, {config.handler_module, state}})
    end

    @doc """
    Sets a process label if the current Elixir version supports it (>= 1.17).
    """
    @spec set(atom(), term()) :: :ok
    def set(name, %ThousandIsland.ServerConfig{} = config) when is_atom(name) do
      Process.set_label({:thousand_island, name, {config.port, config.handler_module}})
    end

    def set(name, state) when is_atom(name) do
      Process.set_label({:thousand_island, name, state})
    end
  else
    @doc """
    No-op on Elixir versions < 1.17 that don't support Process.set_label/1.
    """
    @spec set(atom(), config(), term()) :: :ok
    def set(_, _, _) do
      :ok
    end

    @doc """
    No-op on Elixir versions < 1.17 that don't support Process.set_label/1.
    """
    @spec set(atom(), term()) :: :ok
    def set(_, _) do
      :ok
    end
  end
end
