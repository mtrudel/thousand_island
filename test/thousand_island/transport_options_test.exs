defmodule ThousandIsland.TransportOptionsTest do
  use ExUnit.Case, async: false

  @certfile Path.expand("../support/cert.pem", __DIR__)
  @keyfile Path.expand("../support/key.pem", __DIR__)

  test "TCP and SSL omit the nodelay default only for Unix domain sockets" do
    unix_path =
      Path.join(
        System.tmp_dir!(),
        "thousand_island_#{System.unique_integer([:positive])}.sock"
      )

    on_exit(fn -> File.rm(unix_path) end)

    for {transport, backend, required_options} <- transports() do
      [
        ip_unix_options,
        ifaddr_unix_options,
        explicit_ip_options,
        explicit_ifaddr_options,
        ip_options
      ] =
        traced_listen_options(transport, backend, [
          [ip: {:local, unix_path}] ++ required_options,
          [ifaddr: {:local, unix_path}] ++ required_options,
          [ip: {:local, unix_path}, nodelay: false] ++ required_options,
          [ifaddr: {:local, unix_path}, nodelay: false] ++ required_options,
          required_options
        ])

      refute :proplists.is_defined(:nodelay, ip_unix_options)
      refute :proplists.is_defined(:nodelay, ifaddr_unix_options)
      assert :proplists.get_value(:nodelay, explicit_ip_options) == false
      assert :proplists.get_value(:nodelay, explicit_ifaddr_options) == false
      assert :proplists.get_value(:nodelay, ip_options) == true
    end
  end

  defp transports do
    [
      {ThousandIsland.Transports.TCP, :gen_tcp, []},
      {ThousandIsland.Transports.SSL, :ssl, [certfile: @certfile, keyfile: @keyfile]}
    ]
  end

  defp traced_listen_options(transport, backend, options_list) do
    Code.ensure_loaded!(backend)

    task =
      Task.async(fn ->
        receive do
          :listen ->
            Enum.each(options_list, fn options ->
              try do
                case transport.listen(0, options) do
                  {:ok, socket} -> transport.close(socket)
                  {:error, _reason} -> :ok
                end
              rescue
                ArgumentError -> :ok
              end
            end)
        end
      end)

    :erlang.trace_pattern({backend, :listen, 2}, true, [])
    :erlang.trace(task.pid, true, [:call])
    send(task.pid, :listen)
    task_pid = task.pid

    try do
      resolved_options =
        Enum.map(options_list, fn _options ->
          assert_receive {:trace, ^task_pid, :call, {^backend, :listen, [0, options]}},
                         1_000

          options
        end)

      Task.await(task)
      resolved_options
    after
      :erlang.trace_pattern({backend, :listen, 2}, false, [])
    end
  end
end
