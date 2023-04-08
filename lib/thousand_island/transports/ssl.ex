defmodule ThousandIsland.Transports.SSL do
  @moduledoc """
  Defines a `ThousandIsland.Transport` implementation based on TCP SSL sockets
  as provided by Erlang's `:ssl` module. For the most part, users of Thousand
  Island will only ever need to deal with this module via `transport_options`
  passed to `ThousandIsland` at startup time. A complete list of such options
  is defined via the `t::ssl.tls_server_option` type. This list can be somewhat
  difficult to decipher; by far the most common values to pass to this transport
  are the following:

  * `keyfile`: An absolute string path to a PEM encoded key to use for SSL
  * `certfile`: An absolute string path to a PEM encoded cert to use for SSL
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

  @type options() :: [:ssl.tls_server_option()]

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

    if not Enum.any?([:keyfile, :key], &:proplists.is_defined(&1, resolved_options)) do
      raise "transport_options must include one of keyfile or key"
    end

    if not Enum.any?([:certfile, :cert], &:proplists.is_defined(&1, resolved_options)) do
      raise "transport_options must include one of certfile or cert"
    end

    :ssl.listen(port, resolved_options)
  end

  @impl ThousandIsland.Transport
  defdelegate accept(listener_socket), to: :ssl, as: :transport_accept

  @impl ThousandIsland.Transport
  defdelegate handshake(socket), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate controlling_process(socket, pid), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate recv(socket, length, timeout), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate send(socket, data), to: :ssl

  @impl ThousandIsland.Transport
  def sendfile(socket, filename, offset, length) do
    # We can't use :file.sendfile here since it works on clear sockets, not ssl
    # sockets. Build our own (much slower and not optimized for large files) version.
    with {:ok, fd} <- :file.open(filename, [:raw]),
         {:ok, data} <- :file.pread(fd, offset, length) do
      case :ssl.send(socket, data) do
        :ok -> {:ok, length}
        {:error, error} -> {:error, error}
      end
    end
  end

  @impl ThousandIsland.Transport
  defdelegate getopts(socket, options), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate setopts(socket, options), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate shutdown(socket, way), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate close(socket), to: :ssl

  @impl ThousandIsland.Transport
  # :ssl's typespec is incorrect
  @dialyzer {:no_match, local_info: 1}
  def local_info(socket) do
    case :ssl.sockname(socket) do
      {:ok, {:local, path}} -> %{address: {:local, path}, port: 0, ssl_cert: nil}
      {:ok, {ip, port}} -> %{address: ip, port: port, ssl_cert: nil}
      other -> other
    end
  end

  @impl ThousandIsland.Transport
  def peer_info(socket) do
    {:ok, {ip, port}} = :ssl.peername(socket)

    cert =
      case :ssl.peercert(socket) do
        {:ok, cert} -> cert
        {:error, _} -> nil
      end

    %{address: ip, port: port, ssl_cert: cert}
  end

  @impl ThousandIsland.Transport
  def secure?, do: true

  @impl ThousandIsland.Transport
  defdelegate getstat(socket), to: :ssl

  @impl ThousandIsland.Transport
  defdelegate negotiated_protocol(socket), to: :ssl
end
