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
        ThousandIsland.ProcessLabel.set(:listener, server_config)

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
    with {:ok, first_socket} <-
           server_config.transport_module.listen(
             server_config.port,
             server_config.transport_options
           ) do
      sockets = [{1, first_socket}]

      case server_config.transport_module.sockname(first_socket) do
        {:ok, local_info} ->
          port = bind_port(local_info, server_config)

          case start_listen_sockets(server_config, port, 2, sockets) do
            {:ok, sockets} -> {:ok, sockets, local_info}
            {:error, reason, sockets} -> close_listen_sockets(server_config, sockets, reason)
          end

        {:error, reason} ->
          close_listen_sockets(server_config, sockets, reason)
      end
    end
  end

  defp start_listen_sockets(server_config, _port, next_id, sockets)
       when next_id > server_config.num_listen_sockets,
       do: {:ok, Enum.reverse(sockets)}

  defp start_listen_sockets(server_config, port, next_id, sockets) do
    case server_config.transport_module.listen(port, server_config.transport_options) do
      {:ok, socket} ->
        start_listen_sockets(server_config, port, next_id + 1, [{next_id, socket} | sockets])

      {:error, reason} ->
        {:error, reason, sockets}
    end
  end

  # A listener bound to port 0 is assigned a concrete port by the operating system; use it for
  # the remaining listeners so that every socket is reachable via the advertised port. Non-IP
  # listeners (Unix domain sockets) have no port to propagate and keep the configured value
  defp bind_port({_ip, port}, _server_config) when is_integer(port), do: port
  defp bind_port(_local_info, server_config), do: server_config.port

  defp close_listen_sockets(server_config, sockets, reason) do
    Enum.each(sockets, fn {_, socket} -> server_config.transport_module.close(socket) end)
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
