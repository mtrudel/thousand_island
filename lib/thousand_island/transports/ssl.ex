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
  * `keyfile: A string path to a PEM encoded key to use for SSL
  * `certfile: A string path to a PEM encoded cert to use for SSL
  * `ip`:  The IP to listen on (defaults to all interfaces). IPs should be 
  described in tuple form (ie: `ip: {1, 2, 3, 4}`). The value `:loopback` can 
  be used to only bind to localhost.

  Unless overridden, this module uses the following default options:

  ```elixir
  backlog: 1024,
  nodelay: true,
  linger: {true, 30},
  send_timeout: 30000,
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

  alias ThousandIsland.Transport

  @behaviour Transport

  @impl Transport
  def listen(port, user_options) do
    default_options = [
      backlog: 1024,
      nodelay: true,
      linger: {true, 30},
      send_timeout: 30000,
      send_timeout_close: true,
      reuseaddr: true
    ]

    hardcoded_options = [mode: :binary, active: false]

    resolved_options =
      default_options |> Keyword.merge(user_options) |> Keyword.merge(hardcoded_options)

    if Keyword.take(resolved_options, [:keyfile, :key]) == [] do
      raise "transport_options must include one of keyfile or key"
    end

    if Keyword.take(resolved_options, [:certfile, :cert]) == [] do
      raise "transport_options must include one of certfile or cert"
    end

    :telemetry.execute(
      [:transport, :listen, :start],
      %{port: port, options: resolved_options, transport: :ssl},
      %{}
    )

    :ssl.listen(port, resolved_options)
  end

  @impl Transport
  def listen_port(listener_socket) do
    case :ssl.sockname(listener_socket) do
      {:ok, {_, port}} -> {:ok, port}
      {:error, _} = error -> error
    end
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
  defdelegate shutdown(socket, way), to: :ssl

  @impl Transport
  defdelegate close(socket), to: :ssl

  @impl Transport
  def local_info(socket) do
    {:ok, {ip_tuple, port}} = :ssl.sockname(socket)
    ip = ip_tuple |> :inet.ntoa() |> to_string()
    %{address: ip, port: port, ssl_cert: nil}
  end

  @impl Transport
  def peer_info(socket) do
    {:ok, {ip_tuple, port}} = :ssl.peername(socket)
    ip = ip_tuple |> :inet.ntoa() |> to_string()

    cert =
      case :ssl.peercert(socket) do
        {:ok, cert} -> cert
        {:error, _} -> nil
      end

    %{address: ip, port: port, ssl_cert: cert}
  end
end
