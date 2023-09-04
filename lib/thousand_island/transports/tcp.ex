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
    * `:any` for all interfaces (i.e.: `0.0.0.0`)
    * `{:local, "/path/to/socket"}` for a Unix domain socket. If this option is used,
      the `port` option *must* be set to `0`

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
  @type listener_socket() :: :inet.socket()
  @type socket() :: :inet.socket()

  @behaviour ThousandIsland.Transport

  @hardcoded_options [mode: :binary, active: false]

  @impl ThousandIsland.Transport
  @spec listen(:inet.port_number(), [:inet.inet_backend() | :gen_tcp.listen_option()]) ::
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
    :gen_tcp.listen(port, resolved_options)
  end

  @impl ThousandIsland.Transport
  @spec accept(listener_socket()) ::
          {:ok, socket()} | {:error, reason}
        when reason: :closed | :system_limit | :inet.posix()
  defdelegate accept(listener_socket), to: :gen_tcp

  @impl ThousandIsland.Transport
  @spec handshake(socket()) :: {:ok, socket()}
  def handshake(socket), do: {:ok, socket}

  @impl ThousandIsland.Transport
  @spec handshake(socket(), options()) :: {:ok, socket()}
  def handshake(socket, _), do: {:ok, socket}

  @impl ThousandIsland.Transport
  @spec controlling_process(socket(), pid()) :: :ok | {:error, reason}
        when reason: :closed | :not_owner | :badarg | :inet.posix()
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
    case :file.open(filename, [:raw]) do
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
  @spec peercert(socket()) :: {:error, :not_secure}
  def peercert(_socket), do: {:error, :not_secure}

  @impl ThousandIsland.Transport
  @spec secure?() :: false
  def secure?, do: false

  @impl ThousandIsland.Transport
  @spec getstat(socket()) :: ThousandIsland.Transport.socket_stats()
  defdelegate getstat(socket), to: :inet

  @impl ThousandIsland.Transport
  @spec negotiated_protocol(socket()) :: {:error, :protocol_not_negotiated}
  def negotiated_protocol(_socket), do: {:error, :protocol_not_negotiated}
end
