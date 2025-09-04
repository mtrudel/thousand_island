defmodule ThousandIsland.Transports.TCP do
  @moduledoc """
  Defines a `ThousandIsland.Transport` implementation based on clear TCP sockets
  as provided by Erlang's `:gen_tcp` module. For the most part, users of Thousand
  Island will only ever need to deal with this module via `transport_options`
  passed to `ThousandIsland` at startup time. A complete list of such options
  is defined via the `t::gen_tcp.listen_option/0` type. This list can be somewhat
  difficult to decipher; by far the most common value to pass to this transport
  is the following:

  * `ip`:  The IP to listen on. Can be specified as:
    * `{1, 2, 3, 4}` for IPv4 addresses
    * `{1, 2, 3, 4, 5, 6, 7, 8}` for IPv6 addresses
    * `:loopback` for local loopback
    * `:any` for all interfaces (i.e.: `0.0.0.0`)
    * `{:local, "/path/to/socket"}` for a Unix domain socket. If this option is used,
      the `port` option *must* be set to `0`

  Unless overridden, this module uses the following default options:

  ```elixir
  backlog: 1024,
  nodelay: true,
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
  @type listener_socket() :: :inet.socket()
  @type socket() :: :inet.socket()

  @behaviour ThousandIsland.Transport

  @hardcoded_options [mode: :binary, active: false]

  @impl ThousandIsland.Transport
  @spec listen(:inet.port_number(), [:inet.inet_backend() | :gen_tcp.listen_option()]) ::
          ThousandIsland.Transport.on_listen()
  def listen(port, user_options) do
    default_options = [
      backlog: 1024,
      nodelay: true,
      send_timeout: 30_000,
      send_timeout_close: true,
      reuseaddr: true
    ]

    # We can't use Keyword functions here because :gen_tcp accepts non-keyword style options
    resolved_options =
      Enum.uniq_by(
        @hardcoded_options ++ user_options ++ default_options,
        fn
          {key, _} when is_atom(key) -> key
          key when is_atom(key) -> key
        end
      )

    # `inet_backend`, if present, needs to be the first option
    sorted_options =
      Enum.sort(resolved_options, fn
        _, {:inet_backend, _} -> false
        _, _ -> true
      end)

    :gen_tcp.listen(port, sorted_options)
  end

  @impl ThousandIsland.Transport
  @spec accept(listener_socket()) :: ThousandIsland.Transport.on_accept()
  defdelegate accept(listener_socket), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec handshake(socket()) :: ThousandIsland.Transport.on_handshake()
  def handshake(socket), do: {:ok, socket}

  @impl ThousandIsland.Transport
  @spec upgrade(socket(), options()) :: ThousandIsland.Transport.on_upgrade()
  def upgrade(_, _), do: {:error, :unsupported_upgrade}

  @impl ThousandIsland.Transport
  @spec controlling_process(socket(), pid()) :: ThousandIsland.Transport.on_controlling_process()
  defdelegate controlling_process(socket, pid), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec recv(socket(), non_neg_integer(), timeout()) :: ThousandIsland.Transport.on_recv()
  defdelegate recv(socket, length, timeout), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec send(socket(), iodata()) :: ThousandIsland.Transport.on_send()
  defdelegate send(socket, data), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec sendfile(
          socket(),
          filename :: String.t(),
          offset :: non_neg_integer(),
          length :: non_neg_integer()
        ) :: ThousandIsland.Transport.on_sendfile()
  def sendfile(socket, filename, offset, length) do
    case :file.open(filename, [:read, :raw, :binary]) do
      {:ok, fd} ->
        try do
          :file.sendfile(fd, socket, offset, length, [])
        after
          :file.close(fd)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl ThousandIsland.Transport
  @spec getopts(socket(), ThousandIsland.Transport.socket_get_options()) ::
          ThousandIsland.Transport.on_getopts()
  defdelegate getopts(socket, options), to: :inet

  @impl ThousandIsland.Transport
  @spec setopts(socket(), ThousandIsland.Transport.socket_set_options()) ::
          ThousandIsland.Transport.on_setopts()
  defdelegate setopts(socket, options), to: :inet

  @impl ThousandIsland.Transport
  @spec shutdown(socket(), ThousandIsland.Transport.way()) ::
          ThousandIsland.Transport.on_shutdown()
  defdelegate shutdown(socket, way), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec close(socket() | listener_socket()) :: :ok
  defdelegate close(socket), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec sockname(socket() | listener_socket()) :: ThousandIsland.Transport.on_sockname()
  defdelegate sockname(socket), to: :inet

  @impl ThousandIsland.Transport
  @spec peername(socket()) :: ThousandIsland.Transport.on_peername()
  defdelegate peername(socket), to: :inet

  @impl ThousandIsland.Transport
  @spec peercert(socket()) :: ThousandIsland.Transport.on_peercert()
  def peercert(_socket), do: {:error, :not_secure}

  @impl ThousandIsland.Transport
  @spec secure?() :: false
  def secure?, do: false

  @impl ThousandIsland.Transport
  @spec getstat(socket()) :: ThousandIsland.Transport.socket_stats()
  defdelegate getstat(socket), to: :inet

  @impl ThousandIsland.Transport
  @spec negotiated_protocol(socket()) :: ThousandIsland.Transport.on_negotiated_protocol()
  def negotiated_protocol(_socket), do: {:error, :protocol_not_negotiated}

  @impl ThousandIsland.Transport
  @spec connection_information(socket()) :: ThousandIsland.Transport.on_connection_information()
  def connection_information(_socket), do: {:error, :not_secure}
end
