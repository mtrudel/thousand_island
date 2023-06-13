defmodule ThousandIsland.Transports.SSL do
  @moduledoc """
  Defines a `ThousandIsland.Transport` implementation based on TCP SSL sockets
  as provided by Erlang's `:ssl` module. For the most part, users of Thousand
  Island will only ever need to deal with this module via `transport_options`
  passed to `ThousandIsland` at startup time. A complete list of such options
  is defined via the `t::ssl.tls_server_option` type. This list can be somewhat
  difficult to decipher; by far the most common values to pass to this transport
  are the following:

  * `keyfile`: The path to a PEM encoded key to use for SSL
  * `certfile`: The path to a PEM encoded cert to use for SSL
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
  @type listener_socket() :: :ssl.sslsocket()
  @type socket() :: :ssl.sslsocket()

  @behaviour ThousandIsland.Transport

  @hardcoded_options [mode: :binary, active: false]

  @impl ThousandIsland.Transport
  @spec listen(:inet.port_number(), [:ssl.tls_server_option()]) ::
          {:ok, listener_socket()} | {:error, reason}
        when reason: :system_limit | :inet.posix()
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
  @spec accept(listener_socket()) :: {:ok, socket()} | {:error, reason}
        when reason: :closed | :system_limit | :inet.posix()
  defdelegate accept(listener_socket), to: :ssl, as: :transport_accept

  @impl ThousandIsland.Transport
  @spec handshake(socket()) ::
          {:ok, socket()} | {:ok, socket(), :ssl.protocol_extensions()} | {:error, reason}
        when reason: :closed | :timeout | :ssl.error_alert()
  defdelegate handshake(socket), to: :ssl

  @impl ThousandIsland.Transport
  @spec controlling_process(socket(), pid()) :: :ok | {:error, reason}
        when reason: :closed | :not_owner | :badarg | :inet.posix()
  defdelegate controlling_process(socket, pid), to: :ssl

  @impl ThousandIsland.Transport
  @spec recv(socket(), non_neg_integer(), timeout()) :: ThousandIsland.Transport.on_recv()
  defdelegate recv(socket, length, timeout), to: :ssl

  @impl ThousandIsland.Transport
  @spec send(socket(), iodata()) :: ThousandIsland.Transport.on_send()
  defdelegate send(socket, data), to: :ssl

  @impl ThousandIsland.Transport
  @spec sendfile(
          socket(),
          filename :: String.t(),
          offset :: non_neg_integer(),
          length :: non_neg_integer()
        ) :: ThousandIsland.Transport.on_sendfile()
  def sendfile(socket, filename, offset, length) do
    # We can't use :file.sendfile here since it works on clear sockets, not ssl
    # sockets. Build our own (much slower and not optimized for large files) version.
    with {:ok, fd} <- :file.open(filename, [:raw]),
         {:ok, data} <- :file.pread(fd, offset, length) do
      case :ssl.send(socket, data) do
        :ok -> {:ok, length}
        {:error, error} -> {:error, error}
      end
    else
      :eof -> {:error, :eof}
      err -> err
    end
  end

  @impl ThousandIsland.Transport
  @spec getopts(socket(), ThousandIsland.Transport.socket_get_options()) ::
          ThousandIsland.Transport.on_getopts()
  defdelegate getopts(socket, options), to: :ssl

  @impl ThousandIsland.Transport
  @spec setopts(socket(), ThousandIsland.Transport.socket_set_options()) ::
          ThousandIsland.Transport.on_setopts()
  defdelegate setopts(socket, options), to: :ssl

  @impl ThousandIsland.Transport
  @spec shutdown(socket(), ThousandIsland.Transport.way()) ::
          ThousandIsland.Transport.on_shutdown()
  defdelegate shutdown(socket, way), to: :ssl

  @impl ThousandIsland.Transport
  @spec close(socket() | listener_socket()) :: ThousandIsland.Transport.on_close()
  defdelegate close(socket), to: :ssl

  # :ssl.sockname/1's typespec is incorrect
  @dialyzer {:no_match, local_info: 1}

  @impl ThousandIsland.Transport
  @spec local_info(socket() | listener_socket()) :: ThousandIsland.Transport.on_local_info()
  defdelegate local_info(socket), to: :ssl, as: :sockname

  # :ssl.peername/1's typespec is incorrect
  @dialyzer {:no_match, peer_info: 1}

  @impl ThousandIsland.Transport
  @spec peer_info(socket()) :: ThousandIsland.Transport.on_peer_info()
  defdelegate peer_info(socket), to: :ssl, as: :peername

  @impl ThousandIsland.Transport
  @spec secure?() :: true
  def secure?, do: true

  @impl ThousandIsland.Transport
  @spec getstat(socket()) :: ThousandIsland.Transport.socket_stats()
  defdelegate getstat(socket), to: :ssl

  @impl ThousandIsland.Transport
  @spec negotiated_protocol(socket()) :: ThousandIsland.Transport.on_negotiated_protocol()
  defdelegate negotiated_protocol(socket), to: :ssl
end
