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
  defdelegate close(socket), to: :gen_tcp
end
