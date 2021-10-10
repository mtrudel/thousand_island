defmodule ThousandIsland.Listener do
  @moduledoc false

  use GenServer, restart: :transient

  alias ThousandIsland.ServerConfig

  def start_link(%ServerConfig{} = config) do
    GenServer.start_link(__MODULE__, config)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def listener_socket(pid) do
    GenServer.call(pid, :listener_socket)
  end

  def listener_port(pid) do
    GenServer.call(pid, :listener_port)
  end

  def init(%ServerConfig{
        port: port,
        transport_module: transport_module,
        transport_opts: transport_opts
      }) do
    case transport_module.listen(port, transport_opts) do
      {:ok, listener_socket} ->
        {:ok, port} = transport_module.listen_port(listener_socket)

        :telemetry.execute([:listener, :start], %{port: port}, %{
          transport_module: transport_module,
          transport_opts: transport_opts
        })

        {:ok, %{listener_socket: listener_socket, transport_module: transport_module}}

      {:error, reason} = error ->
        :telemetry.execute(
          [:listener, :error],
          %{
            error: reason
          },
          %{
            transport_module: transport_module,
            transport_opts: transport_opts
          }
        )

        {:stop, error}
    end
  end

  def handle_call(:listener_socket, _from, %{listener_socket: listener_socket} = state) do
    {:reply, {:ok, listener_socket}, state}
  end

  def handle_call(
        :listener_port,
        _from,
        %{listener_socket: listener_socket, transport_module: transport_module} = state
      ) do
    {:reply, transport_module.listen_port(listener_socket), state}
  end

  def terminate(_reason, %{transport_module: transport_module}) do
    :telemetry.execute([:listener, :shutdown], %{}, %{transport_module: transport_module})
  end
end
