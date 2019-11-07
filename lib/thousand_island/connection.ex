defmodule ThousandIsland.Connection do
  use Task

  require Logger

  def start_link(args) do
    Task.start_link(__MODULE__, :run, [args])
  end

  def run({socket, opts}) do
    transport_module = Keyword.get(opts, :transport_module, ThousandIsland.Transports.TCP)

    try do
      Logger.debug(fn ->
        {:ok, {remote_ip_tuple, remote_port}} = :inet.peername(socket)
        remote_ip = :inet.ntoa(remote_ip_tuple)
        "Connection #{inspect(self())} starting up (remote #{remote_ip}:#{remote_port})"
      end)

      {:ok, _} = transport_module.recv(socket, 0)
      transport_module.send(socket, "HTTP/1.1 200\r\n\r\nHello")

      Logger.debug("Connection #{inspect(self())} shutting down")
    after
      transport_module.close(socket)
    end
  end
end
