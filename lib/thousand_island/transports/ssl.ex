defmodule ThousandIsland.Transports.SSL do
  @moduledoc """
  Defines a `ThousandIsland.Transport` implementation based on TCP SSL sockets
  as provided by Erlang's `:ssl` module. For the most part, users of Thousand
  Island will only ever need to deal with this module via `transport_options`
  passed to `ThousandIsland` at startup time. A complete list of such options
  is defined via the `t::ssl.tls_server_option` type. This list can be somewhat
  difficult to decipher; a list of the most common options follows:

  * `key`: A DER encoded binary representation of the SSL key to use
  * `cert`: A DER encoded binary representation of the SSL key to use
  * `keyfile`: A string path to a PEM encoded key to use for SSL
  * `certfile`: A string path to a PEM encoded cert to use for SSL
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

  @type options() :: [:ssl.tls_server_option()]

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

    if !(:proplists.is_defined(:keyfile, resolved_options) ||
           :proplists.is_defined(:key, resolved_options)) do
      raise "transport_options must include one of keyfile or key"
    end

    if !(:proplists.is_defined(:certfile, resolved_options) ||
           :proplists.is_defined(:cert, resolved_options)) do
      raise "transport_options must include one of certfile or cert"
    end

    :ssl.listen(port, resolved_options)
  end

  @impl Transport
  defdelegate accept(listener_socket), to: :ssl, as: :transport_accept

  @impl Transport
  defdelegate handshake(socket), to: :ssl

  @impl Transport
  defdelegate controlling_process(socket, pid), to: :ssl

  @impl Transport
  defdelegate recv(socket, length, timeout), to: :ssl

  @impl Transport
  defdelegate send(socket, data), to: :ssl

  @impl Transport
  def sendfile(socket, filename, offset, length) do
    # We can't use :file.sendfile here since it works on clear sockets, not ssl
    # sockets. Build our own (much slower and not optimized for large files) version.
    with {:ok, fd} <- :file.open(filename, [:raw]),
         {:ok, data} <- :file.pread(fd, offset, length) do
      :ssl.send(socket, data)
    end
  end

  @impl Transport
  defdelegate getopts(socket, options), to: :ssl

  @impl Transport
  defdelegate setopts(socket, options), to: :ssl

  @impl Transport
  defdelegate shutdown(socket, way), to: :ssl

  @impl Transport
  defdelegate close(socket), to: :ssl

  @impl Transport
  # :ssl's typespec is incorrect
  @dialyzer {:no_match, local_info: 1}
  def local_info(socket) do
    case :ssl.sockname(socket) do
      {:ok, {:local, path}} -> %{address: {:local, path}, port: 0, ssl_cert: nil}
      {:ok, {ip, port}} -> %{address: ip, port: port, ssl_cert: nil}
      other -> other
    end
  end

  @impl Transport
  def peer_info(socket) do
    {:ok, {ip, port}} = :ssl.peername(socket)

    cert =
      case :ssl.peercert(socket) do
        {:ok, cert} -> cert
        {:error, _} -> nil
      end

    %{address: ip, port: port, ssl_cert: cert}
  end

  @impl Transport
  def secure?, do: true

  @impl Transport
  defdelegate getstat(socket), to: :ssl

  @impl Transport
  defdelegate negotiated_protocol(socket), to: :ssl
end
