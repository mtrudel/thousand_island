defmodule ThousandIsland do
  alias ThousandIsland.{Listener, Server, ServerConfig}

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def start_link(opts \\ []) do
    opts
    |> ServerConfig.new()
    |> Server.start_link()
  end

  def local_port(pid) do
    pid |> Server.listener_pid() |> Listener.listener_port()
  end
end
