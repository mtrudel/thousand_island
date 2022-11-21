defmodule ThousandIsland.Transports.TCP do
  @moduledoc """
  Defines a `ThousandIsland.Transport` implementation based on clear TCP sockets
  as provided by Erlang's `:gen_tcp` module. For the most part, users of Thousand
  Island will only ever need to deal with this module via `transport_options`
  passed to `ThousandIsland` at startup time. A complete list of such options
  is defined via the `t::gen_tcp.listen_option()` type. This list can be somewhat
  difficult to decipher; by far the most common value to pass to this transport
  is the following:

  * `ip`:  The IP to listen on (defaults to all interfaces). IPs should be
  described in tuple form (ie: `ip: {1, 2, 3, 4}`). The value `:loopback` can
  be used to only bind to localhost. On platforms which support it (macOS and
  Linux at a minimum, likely others), you can also bind to a Unix domain socket
  by specifying a value of `ip: {:local, "/path/to/socket"}`. Note that the port
  *must* be set to `0`, and that the socket is not removed from the filesystem
  after the server shuts down.

  Unless overridden, this module uses the following default options:

  ```elixir
  backlog: 1024,
  nodelay: true,
  linger: {true, 30},
  send_timeout: 30_000,
  send_timeout_close: true,
  reuseaddr: true
  ```

  The following options are required for the proper operation of Thousand Island
  and cannot be overridden at startup (though they can be set via calls to `setopts/2`)

  ```elixir
  mode: :binary,
  active: false
  ```
  """

  alias ThousandIsland.Transport

  @type options() :: [:gen_tcp.listen_option()]

  @behaviour Transport

  @hardcoded_options [mode: :binary, active: false]

  @impl Transport
  def listen(port, user_options) do
    default_options = [
      backlog: 1024,
      nodelay: true,
      linger: {true, 30},
      send_timeout: 30_000,
      send_timeout_close: true,
      reuseaddr: true
    ]

    resolved_options = @hardcoded_options ++ user_options ++ default_options
    :gen_tcp.listen(port, resolved_options)
  end

  @impl Transport
  defdelegate accept(listener_socket), to: :gen_tcp

  @impl Transport
  def handshake(socket), do: {:ok, socket}

  @impl Transport
  defdelegate controlling_process(socket, pid), to: :gen_tcp

  @impl Transport
  defdelegate recv(socket, length, timeout), to: :gen_tcp

  @impl Transport
  defdelegate send(socket, data), to: :gen_tcp

  @impl Transport
  def sendfile(socket, filename, offset, length) do
    with {:ok, fd} <- :file.open(filename, [:raw]) do
      :file.sendfile(fd, socket, offset, length, [])
    end
  end

  @impl Transport
  defdelegate getopts(socket, options), to: :inet

  @impl Transport
  defdelegate setopts(socket, options), to: :inet

  @impl Transport
  defdelegate shutdown(socket, way), to: :gen_tcp

  @impl Transport
  defdelegate close(socket), to: :gen_tcp

  @impl Transport
  def local_info(socket) do
    case :inet.sockname(socket) do
      {:ok, {:local, path}} -> %{address: {:local, path}, port: 0, ssl_cert: nil}
      {:ok, {ip, port}} -> %{address: ip, port: port, ssl_cert: nil}
      other -> other
    end
  end

  @impl Transport
  def peer_info(socket) do
    {:ok, {ip, port}} = :inet.peername(socket)
    %{address: ip, port: port, ssl_cert: nil}
  end

  @impl Transport
  def secure?, do: false

  @impl Transport
  defdelegate getstat(socket), to: :inet

  @impl Transport
  def negotiated_protocol(_socket), do: {:error, :protocol_not_negotiated}
end
