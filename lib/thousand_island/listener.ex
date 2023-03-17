defmodule ThousandIsland.Listener do
  @moduledoc false

  use GenServer, restart: :transient

  def start_link(config), do: GenServer.start_link(__MODULE__, config)
  def stop(pid), do: GenServer.stop(pid)
  def listener_info(pid), do: GenServer.call(pid, :listener_info)
  def acceptor_info(pid), do: GenServer.call(pid, :acceptor_info)

  def init(%ThousandIsland.ServerConfig{} = server_config) do
    case server_config.transport_module.listen(
           server_config.port,
           server_config.transport_options
         ) do
      {:ok, listener_socket} ->
        local_info = server_config.transport_module.local_info(listener_socket)

        span_meta = %{
          local_address: local_info.address,
          local_port: local_info.port,
          transport_module: server_config.transport_module,
          transport_options: server_config.transport_options
        }

        span = ThousandIsland.Telemetry.start_span(:listener, %{}, span_meta)

        {:ok, %{listener_socket: listener_socket, local_info: local_info, span: span}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_call(:listener_info, _from, state), do: {:reply, state.local_info, state}

  def handle_call(:acceptor_info, _from, state),
    do: {:reply, {state.listener_socket, state.span}, state}

  def terminate(_reason, state), do: ThousandIsland.Telemetry.stop_span(state.span)
end
