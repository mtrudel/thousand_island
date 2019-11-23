defmodule ThousandIsland.Transports.SSL do
  alias ThousandIsland.Transport

  @behaviour Transport

  @impl Transport
  def listen(opts) do
    port = Keyword.get(opts, :port, 4000)

    default_options = [
      backlog: 1024,
      nodelay: true,
      linger: {true, 30},
      send_timeout: 30000,
      send_timeout_close: true,
      reuseaddr: true
    ]

    user_options = Keyword.get(opts, :transport_options, [])
    hardcoded_options = [mode: :binary, active: false]

    resolved_options =
      default_options |> Keyword.merge(user_options) |> Keyword.merge(hardcoded_options)

    :telemetry.execute(
      [:transport, :listen, :start],
      %{port: port, options: resolved_options, transport: :ssl},
      %{}
    )

    :ssl.listen(port, resolved_options)
  end

  @impl Transport
  def accept(listener_socket) do
    with {:ok, ssl_socket} <- :ssl.transport_accept(listener_socket) do
      :ssl.handshake(ssl_socket)
    end
  end

  @impl Transport
  defdelegate recv(socket, length, timeout), to: :ssl

  @impl Transport
  defdelegate send(socket, data), to: :ssl

  @impl Transport
  defdelegate shutdown(socket, way), to: :ssl

  @impl Transport
  defdelegate close(socket), to: :ssl

  @impl Transport
  def local_info(socket) do
    {:ok, {ip_tuple, port}} = :ssl.sockname(socket)
    ip = ip_tuple |> :inet.ntoa() |> to_string()
    %{address: ip, port: port, ssl_cert: nil}
  end

  @impl Transport
  def peer_info(socket) do
    {:ok, {ip_tuple, port}} = :ssl.peername(socket)
    ip = ip_tuple |> :inet.ntoa() |> to_string()

    cert =
      case :ssl.peercert(socket) do
        {:ok, cert} -> cert
        {:error, _} -> nil
      end

    %{address: ip, port: port, ssl_cert: cert}
  end
end
