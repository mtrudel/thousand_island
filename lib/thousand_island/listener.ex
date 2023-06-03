defmodule ThousandIsland.Listener do
  @moduledoc false

  use GenServer, restart: :transient

  @type state :: %{
          listener_socket: ThousandIsland.Transport.listener_socket(),
          local_info: ThousandIsland.Transport.socket_info(),
          span: ThousandIsland.Telemetry.t()
        }

  @spec start_link(ThousandIsland.ServerConfig.t()) :: GenServer.on_start()
  def start_link(config), do: GenServer.start_link(__MODULE__, config)

  @spec stop(GenServer.server()) :: :ok
  def stop(server), do: GenServer.stop(server)

  @spec listener_info(GenServer.server()) :: ThousandIsland.Transport.socket_info()
  def listener_info(server), do: GenServer.call(server, :listener_info)

  @spec acceptor_info(GenServer.server()) ::
          {ThousandIsland.Transport.listener_socket(), ThousandIsland.Telemetry.t()}
  def acceptor_info(server), do: GenServer.call(server, :acceptor_info)

  @impl GenServer
  @spec init(ThousandIsland.ServerConfig.t()) :: {:ok, state} | {:stop, reason :: term}
  def init(%ThousandIsland.ServerConfig{} = server_config) do
    case server_config.transport_module.listen(
           server_config.port,
           server_config.transport_options
         ) do
      {:ok, listener_socket} ->
        local_info = server_config.transport_module.local_info(listener_socket)

        span =
          ThousandIsland.Telemetry.start_listener_span(
            local_info.address,
            local_info.port,
            server_config.transport_module,
            server_config.transport_options
          )

        {:ok, %{listener_socket: listener_socket, local_info: local_info, span: span}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  @spec handle_call(:listener_info | :acceptor_info, any, state) ::
          {:reply,
           ThousandIsland.Transport.socket_info()
           | {ThousandIsland.Transport.socket_info(), ThousandIsland.Telemetry.t()}, state}
  def handle_call(:listener_info, _from, state), do: {:reply, state.local_info, state}

  def handle_call(:acceptor_info, _from, state),
    do: {:reply, {state.listener_socket, state.span}, state}

  @impl GenServer
  @spec terminate(reason, state) :: :ok
        when reason: :normal | :shutdown | {:shutdown, term} | term
  def terminate(_reason, state), do: ThousandIsland.Telemetry.stop_listener_span(state.span)
end
