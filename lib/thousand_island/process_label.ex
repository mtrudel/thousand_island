defmodule ThousandIsland.ProcessLabel do
  @moduledoc false
  # Provides compile-time conditional support for Process.set_label/1
  # which was introduced in Elixir 1.17.0
  @supports_labels Version.match?(System.version(), ">= 1.17.0")

  if @supports_labels do
    @doc """
    Sets a process label if the current Elixir version supports it (>= 1.17).
    """
    @spec set(term() | [term()]) :: :ok
    def set(labels) when is_list(labels) do
      Process.set_label([:thousand_island | labels])
    end

    def set(label) do
      Process.set_label([:thousand_island, label])
    end
  else
    @doc """
    No-op on Elixir versions < 1.17 that don't support Process.set_label/1.
    """
    @spec set(term() | [term()]) :: :ok
    def set(_labels) do
      :ok
    end
  end
end
