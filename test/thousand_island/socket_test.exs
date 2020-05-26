defmodule ThousandIsland.SocketTest do
  use ExUnit.Case, async: true

  alias ThousandIsland.Handlers

  def gen_tcp_setup(_context) do
    {:ok, %{client_mod: :gen_tcp, server_opts: []}}
  end

  def ssl_setup(_context) do
    {:ok,
     %{
       client_mod: :ssl,
       server_opts: [
         transport_module: ThousandIsland.Transports.SSL,
         transport_options: [
           certfile: Path.join(__DIR__, "../support/cert.pem"),
           keyfile: Path.join(__DIR__, "../support/key.pem")
         ]
       ]
     }}
  end

  [:gen_tcp_setup, :ssl_setup]
  |> Enum.each(fn setup_fn ->
    describe "common behaviour using #{setup_fn}" do
      setup setup_fn

      test "should satisfy a basic echo transport handler", context do
        {:ok, port} = start_handler(Handlers.Echo, context.server_opts)
        {:ok, client} = context.client_mod.connect(:localhost, port, active: false)

        assert context.client_mod.send(client, "HELLO") == :ok
        assert context.client_mod.recv(client, 0) == {:ok, 'HELLO'}

        context.client_mod.close(client)
      end
    end
  end)

  describe "behaviour specific to gen_tcp" do
    setup :gen_tcp_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Handlers.Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(:localhost, port, active: false)
      {:ok, resp} = context.client_mod.recv(client, 0)
      {:ok, local_port} = :inet.port(client)

      assert to_string(resp) ==
               "[%{address: \"127.0.0.1\", port: #{port}, ssl_cert: nil}, %{address: \"127.0.0.1\", port: #{
                 local_port
               }, ssl_cert: nil}]"

      context.client_mod.close(client)
    end
  end

  describe "behaviour specific to ssl" do
    setup :ssl_setup

    test "it should provide correct connection info", context do
      {:ok, port} = start_handler(Handlers.Info, context.server_opts)
      {:ok, client} = context.client_mod.connect(:localhost, port, active: false)
      {:ok, {_, local_port}} = context.client_mod.sockname(client)
      {:ok, resp} = context.client_mod.recv(client, 0)

      assert to_string(resp) ==
               "[%{address: \"127.0.0.1\", port: #{port}, ssl_cert: nil}, %{address: \"127.0.0.1\", port: #{
                 local_port
               }, ssl_cert: nil}]"

      context.client_mod.close(client)
    end
  end

  defp start_handler(handler, server_args) do
    resolved_args = server_args |> Keyword.merge(port: 0, handler_module: handler)
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    ThousandIsland.local_port(server_pid)
  end
end
