defmodule ThousandIsland.Transports.TCP do
  @behaviour ThousandIsland.Transport

  require Logger

  @impl ThousandIsland.Transport
  def listen(opts) do
    port = Keyword.get(opts, :port, 4000)
    result = :gen_tcp.listen(port, mode: :binary, active: false, reuseaddr: true)
    Logger.info("Listening on port #{port}")
    result
  end

  @impl ThousandIsland.Transport
  defdelegate accept(listener_socket), to: :gen_tcp

  @impl ThousandIsland.Transport
  defdelegate recv(socket, length), to: :gen_tcp

  @impl ThousandIsland.Transport
  defdelegate send(socket, data), to: :gen_tcp

  @impl ThousandIsland.Transport
  defdelegate close(socket), to: :gen_tcp
end
