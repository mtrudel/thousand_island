defmodule ThousandIsland.Listener do
  @moduledoc false

  use GenServer, restart: :transient

  @type state :: %{
          listener_sockets: [{pos_integer(), ThousandIsland.Transport.listener_socket()}],
          listener_span: ThousandIsland.Telemetry.t(),
          local_info: ThousandIsland.Transport.socket_info()
        }

  @spec start_link(ThousandIsland.ServerConfig.t()) :: GenServer.on_start()
  def start_link(config), do: GenServer.start_link(__MODULE__, config)

  @spec stop(GenServer.server()) :: :ok
  def stop(server), do: GenServer.stop(server)

  @spec listener_info(GenServer.server()) :: ThousandIsland.Transport.socket_info()
  def listener_info(server), do: GenServer.call(server, :listener_info)

  @spec acceptor_info(GenServer.server(), pos_integer()) ::
          {ThousandIsland.Transport.listener_socket(), ThousandIsland.Telemetry.t()}
  def acceptor_info(server, acceptor_id),
    do: GenServer.call(server, {:acceptor_info, acceptor_id})

  @impl GenServer
  @spec init(ThousandIsland.ServerConfig.t()) :: {:ok, state} | {:stop, reason :: term}
  def init(%ThousandIsland.ServerConfig{} = server_config) do
    case start_listen_sockets(server_config) do
      {:ok, listener_sockets, local_info} ->
        span_metadata = %{
          handler: server_config.handler_module,
          local_address: elem(local_info, 0),
          local_port: elem(local_info, 1),
          transport_module: server_config.transport_module,
          transport_options: server_config.transport_options
        }

        listener_span = ThousandIsland.Telemetry.start_span(:listener, %{}, span_metadata)

        {:ok,
         %{
           listener_sockets: listener_sockets,
           local_info: local_info,
           listener_span: listener_span
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp start_listen_sockets(%ThousandIsland.ServerConfig{} = server_config) do
    num_sockets = server_config.num_listen_sockets

    sockets =
      for socket_id <- 1..num_sockets do
        case server_config.transport_module.listen(
               server_config.port,
               server_config.transport_options
             ) do
          {:ok, socket} -> {socket_id, socket}
          {:error, reason} -> throw({:error, reason})
        end
      end

    # Get local info from first socket
    {1, first_socket} = List.keyfind(sockets, 1, 0)

    case server_config.transport_module.sockname(first_socket) do
      {:ok, {ip, port}} ->
        {:ok, sockets, {ip, port}}

      {:error, reason} ->
        # Cleanup all sockets on error
        Enum.each(sockets, fn {_, socket} ->
          server_config.transport_module.close(socket)
        end)

        {:error, reason}
    end
  catch
    {:error, reason} ->
      {:error, reason}
  end

  @impl GenServer
  @spec handle_call(:listener_info | {:acceptor_info, pos_integer()}, any, state) ::
          {:reply,
           ThousandIsland.Transport.socket_info()
           | {ThousandIsland.Transport.listener_socket(), ThousandIsland.Telemetry.t()}, state}
  def handle_call(:listener_info, _from, state), do: {:reply, state.local_info, state}

  def handle_call({:acceptor_info, acceptor_id}, _from, state) do
    num_listen_sockets = length(state.listener_sockets)
    socket_id = rem(acceptor_id - 1, num_listen_sockets) + 1
    {^socket_id, listener_socket} = List.keyfind(state.listener_sockets, socket_id, 0)
    {:reply, {listener_socket, state.listener_span}, state}
  end

  @impl GenServer
  @spec terminate(reason, state) :: :ok
        when reason: :normal | :shutdown | {:shutdown, term} | term
  def terminate(_reason, state) do
    ThousandIsland.Telemetry.stop_span(state.listener_span)
  end
end
