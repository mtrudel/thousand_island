defmodule ThousandIsland.Transports.TCP do
  @moduledoc """
  Defines a `ThousandIsland.Transport` implementation based on clear TCP sockets
  as provided by Erlang's `:gen_tcp` module. For the most part, users of Thousand
  Island will only ever need to deal with this module via `transport_options`
  passed to `ThousandIsland` at startup time. A complete list of such options
  is defined via the `t::gen_tcp.listen_option()` type. This list can be somewhat
  difficult to decipher; by far the most common value to pass to this transport
  is the following:

  * `ip`:  The IP to listen on. Can be specified as:
    * `{1, 2, 3, 4}` for IPv4 addresses
    * `{1, 2, 3, 4, 5, 6, 7, 8}` for IPv6 addresses
    * `:loopback` for local loopback
    * `:any` for all interfaces (ie: `0.0.0.0`)
    * `{:local, "/path/to/socket"}` for a Unix domain socket. If this option is used, the `port`
      option *must* be set to `0`.

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
  and cannot be overridden:

  ```elixir
  mode: :binary,
  active: false
  ```
  """

  @type options() :: [:gen_tcp.listen_option()]

  @behaviour ThousandIsland.Transport

  @hardcoded_options [mode: :binary, active: false]

  @impl ThousandIsland.Transport
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

  @impl ThousandIsland.Transport
  defdelegate accept(listener_socket), to: :gen_tcp

  @impl ThousandIsland.Transport
  def handshake(socket), do: {:ok, socket}

  @impl ThousandIsland.Transport
  defdelegate controlling_process(socket, pid), to: :gen_tcp

  @impl ThousandIsland.Transport
  defdelegate recv(socket, length, timeout), to: :gen_tcp

  @impl ThousandIsland.Transport
  defdelegate send(socket, data), to: :gen_tcp

  @impl ThousandIsland.Transport
  def sendfile(socket, filename, offset, length) do
    with {:ok, fd} <- :file.open(filename, [:raw]) do
      :file.sendfile(fd, socket, offset, length, [])
    end
  end

  @impl ThousandIsland.Transport
  defdelegate getopts(socket, options), to: :inet

  @impl ThousandIsland.Transport
  defdelegate setopts(socket, options), to: :inet

  @impl ThousandIsland.Transport
  defdelegate shutdown(socket, way), to: :gen_tcp

  @impl ThousandIsland.Transport
  defdelegate close(socket), to: :gen_tcp

  @impl ThousandIsland.Transport
  def local_info(socket) do
    case :inet.sockname(socket) do
      {:ok, {:local, path}} -> %{address: {:local, path}, port: 0, ssl_cert: nil}
      {:ok, {ip, port}} -> %{address: ip, port: port, ssl_cert: nil}
      other -> other
    end
  end

  @impl ThousandIsland.Transport
  def peer_info(socket) do
    {:ok, {ip, port}} = :inet.peername(socket)
    %{address: ip, port: port, ssl_cert: nil}
  end

  @impl ThousandIsland.Transport
  def secure?, do: false

  @impl ThousandIsland.Transport
  defdelegate getstat(socket), to: :inet

  @impl ThousandIsland.Transport
  def negotiated_protocol(_socket), do: {:error, :protocol_not_negotiated}
end
