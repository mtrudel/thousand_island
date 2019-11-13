defmodule ThousandIsland.Transports.TCP do
  require Logger

  alias ThousandIsland.Transport

  @behaviour Transport

  @impl Transport
  def listen(opts) do
    port = Keyword.get(opts, :port, 4000)
    result = :gen_tcp.listen(port, mode: :binary, active: false, reuseaddr: true)
    Logger.info("Listening on port #{port}")
    result
  end

  @impl Transport
  defdelegate accept(listener_socket), to: :gen_tcp

  @impl Transport
  defdelegate recv(socket, length), to: :gen_tcp

  @impl Transport
  defdelegate send(socket, data), to: :gen_tcp

  @impl Transport
  defdelegate shutdown(socket, way), to: :gen_tcp

  @impl Transport
  defdelegate close(socket), to: :gen_tcp

  @impl Transport
  def endpoints(socket) do
    {:ok, {local_ip_tuple, local_port}} = :inet.sockname(socket)
    local_ip = :inet.ntoa(local_ip_tuple)
    {:ok, {remote_ip_tuple, remote_port}} = :inet.peername(socket)
    remote_ip = :inet.ntoa(remote_ip_tuple)
    {{local_ip, local_port}, {remote_ip, remote_port}}
  end
end
