defmodule ThousandIsland.Transport do
  @moduledoc """
  This module describes the behaviour required for Thousand Island to interact
  with low-level sockets. It is largely internal to Thousand Island, however users
  are free to implement their own versions of this behaviour backed by whatever
  underlying transport they choose. Such a module can be used in Thousand Island
  by passing its name as the `transport_module` option when starting up a server,
  as described in `ThousandIsland`.
  """

  @typedoc "A listener socket used to wait for connections"
  @type listener_socket() :: :inet.socket() | :ssl.sslsocket()

  @typedoc "A listener socket options"
  @type listen_options() ::
          [:inet.inet_backend() | :gen_tcp.listen_option()] | [:ssl.tls_server_option()]

  @typedoc "A socket representing a client connection"
  @type socket() :: :inet.socket() | :ssl.sslsocket()

  @typedoc "Information about an endpoint, either remote ('peer') or local"
  @type socket_info() ::
          {:inet.ip_address(), :inet.port_number()} | :inet.returned_non_ip_address()

  @typedoc "A socket address"
  @type address ::
          :inet.ip_address()
          | :inet.local_address()
          | {:local, binary()}
          | :unspec
          | {:undefined, any()}
  @typedoc "Connection statistics for a given socket"
  @type socket_stats() :: {:ok, [{:inet.stat_option(), integer()}]} | {:error, :inet.posix()}

  @typedoc "Options which can be set on a socket via setopts/2 (or returned from getopts/1)"
  @type socket_get_options() :: [:inet.socket_getopt()]

  @typedoc "Options which can be set on a socket via setopts/2 (or returned from getopts/1)"
  @type socket_set_options() :: [:inet.socket_setopt()]

  @typedoc "The direction in which to shutdown a connection in advance of closing it"
  @type way() :: :read | :write | :read_write

  @typedoc "The return value from a listen/2 call"
  @type on_listen() ::
          {:ok, listener_socket()} | {:error, :system_limit} | {:error, :inet.posix()}

  @typedoc "The return value from an accept/1 call"
  @type on_accept() :: {:ok, socket()} | {:error, on_accept_tcp_error() | on_accept_ssl_error()}

  @type on_accept_tcp_error() :: :closed | :system_limit | :inet.posix()
  @type on_accept_ssl_error() :: :closed | :timeout | :ssl.error_alert()

  @typedoc "The return value from a controlling_process/2 call"
  @type on_controlling_process() :: :ok | {:error, :closed | :not_owner | :badarg | :inet.posix()}

  @typedoc "The return value from a handshake/1 call"
  @type on_handshake() :: {:ok, socket()} | {:error, on_handshake_ssl_error()}

  @type on_handshake_ssl_error() :: :closed | :timeout | :ssl.error_alert()

  @typedoc "The return value from a upgrade/2 call"
  @type on_upgrade() :: {:ok, socket()} | {:error, term()}

  @typedoc "The return value from a shutdown/2 call"
  @type on_shutdown() :: :ok | {:error, :inet.posix()}

  @typedoc "The return value from a close/1 call"
  @type on_close() :: :ok | {:error, any()}

  @typedoc "The return value from a recv/3 call"
  @type on_recv() :: {:ok, binary()} | {:error, :closed | :timeout | :inet.posix()}

  @typedoc "The return value from a send/2 call"
  @type on_send() :: :ok | {:error, :closed | {:timeout, rest_data :: binary()} | :inet.posix()}

  @typedoc "The return value from a sendfile/4 call"
  @type on_sendfile() ::
          {:ok, non_neg_integer()}
          | {:error, :inet.posix() | :closed | :badarg | :not_owner | :eof}

  @typedoc "The return value from a getopts/2 call"
  @type on_getopts() :: {:ok, [:inet.socket_optval()]} | {:error, :inet.posix()}

  @typedoc "The return value from a setopts/2 call"
  @type on_setopts() :: :ok | {:error, :inet.posix()}

  @typedoc "The return value from a sockname/1 call"
  @type on_sockname() :: {:ok, socket_info()} | {:error, :inet.posix()}

  @typedoc "The return value from a peername/1 call"
  @type on_peername() :: {:ok, socket_info()} | {:error, :inet.posix()}

  @typedoc "The return value from a peercert/1 call"
  @type on_peercert() :: {:ok, :public_key.der_encoded()} | {:error, reason :: any()}

  @typedoc "The return value from a connection_information/1 call"
  @type on_connection_information() :: {:ok, :ssl.connection_info()} | {:error, reason :: any()}

  @typedoc "The return value from a negotiated_protocol/1 call"
  @type on_negotiated_protocol() ::
          {:ok, binary()} | {:error, :protocol_not_negotiated | :closed}

  @doc """
  Create and return a listener socket bound to the given port and configured per
  the provided options.
  """
  @callback listen(:inet.port_number(), listen_options()) ::
              {:ok, listener_socket()} | {:error, any()}

  @doc """
  Wait for a client connection on the given listener socket. This call blocks until
  such a connection arrives, or an error occurs (such as the listener socket being
  closed).
  """
  @callback accept(listener_socket()) :: on_accept()

  @doc """
  Performs an initial handshake on a new client connection (such as that done
  when negotiating an SSL connection). Transports which do not have such a
  handshake can simply pass the socket through unchanged.
  """
  @callback handshake(socket()) :: on_handshake()

  @doc """
  Performs an upgrade of an existing client connection (for example upgrading
  an already-established connection to SSL). Transports which do not support upgrading can return
  `{:error, :unsupported_upgrade}`.
  """
  @callback upgrade(socket(), term()) :: on_upgrade()

  @doc """
  Transfers ownership of the given socket to the given process. This will always
  be called by the process which currently owns the socket.
  """
  @callback controlling_process(socket(), pid()) :: on_controlling_process()

  @doc """
  Returns available bytes on the given socket. Up to `num_bytes` bytes will be
  returned (0 can be passed in to get the next 'available' bytes, typically the
  next packet). If insufficient bytes are available, the function can wait `timeout`
  milliseconds for data to arrive.
  """
  @callback recv(socket(), num_bytes :: non_neg_integer(), timeout :: timeout()) :: on_recv()

  @doc """
  Sends the given data (specified as a binary or an IO list) on the given socket.
  """
  @callback send(socket(), data :: iodata()) :: on_send()

  @doc """
  Sends the contents of the given file based on the provided offset & length
  """
  @callback sendfile(
              socket(),
              filename :: String.t(),
              offset :: non_neg_integer(),
              length :: non_neg_integer()
            ) :: on_sendfile()

  @doc """
  Gets the given options on the socket.
  """
  @callback getopts(socket(), socket_get_options()) :: on_getopts()

  @doc """
  Sets the given options on the socket. Should disallow setting of options which
  are not compatible with Thousand Island
  """
  @callback setopts(socket(), socket_set_options()) :: on_setopts()

  @doc """
  Shuts down the socket in the given direction.
  """
  @callback shutdown(socket(), way()) :: on_shutdown()

  @doc """
  Closes the given socket.
  """
  @callback close(socket() | listener_socket()) :: on_close()

  @doc """
  Returns information in the form of `t:socket_info()` about the local end of the socket.
  """
  @callback sockname(socket() | listener_socket()) :: on_sockname()

  @doc """
  Returns information in the form of `t:socket_info()` about the remote end of the socket.
  """
  @callback peername(socket()) :: on_peername()

  @doc """
  Returns the peer certificate for the given socket in the form of `t:public_key.der_encoded()`.
  If the socket is not secure, `{:error, :not_secure}` is returned.
  """
  @callback peercert(socket()) :: on_peercert()

  @doc """
  Returns whether or not this protocol is secure.
  """
  @callback secure?() :: boolean()

  @doc """
  Returns stats about the connection on the socket.
  """
  @callback getstat(socket()) :: socket_stats()

  @doc """
  Returns the protocol negotiated as part of handshaking. Most typically this is via TLS'
  ALPN or NPN extensions. If the underlying transport does not support protocol negotiation
  (or if one was not negotiated), `{:error, :protocol_not_negotiated}` is returned
  """
  @callback negotiated_protocol(socket()) :: on_negotiated_protocol()

  @doc """
  Returns the SSL connection_info for the given socket. If the socket is not secure,
  `{:error, :not_secure}` is returned.
  """
  @callback connection_information(socket()) :: on_connection_information()
end
