defmodule ThousandIsland.ConfigTest do
  use ExUnit.Case, async: true
  use Machete

  alias ThousandIsland.ServerConfig

  describe "server_config exceptions" do
    test "raises exception when handler_module is nil" do
      assert_raise RuntimeError, fn ->
        ServerConfig.new(port: 4000, handler_module: nil)
      end
    end

    test "raises exception when num_listen_sockets > num_acceptors" do
      assert_raise RuntimeError, fn ->
        ServerConfig.new(
          port: 4000,
          handler_module: __MODULE__,
          num_listen_sockets: 5,
          num_acceptors: 3
        )
      end
    end

    test "raises ArgumentError when num_listen_sockets > 1 without reuseport options" do
      assert_raise ArgumentError, fn ->
        ServerConfig.new(
          port: 4000,
          handler_module: __MODULE__,
          num_listen_sockets: 2,
          transport_options: []
        )
      end
    end

    test "num_listen_sockets defaults to 1" do
      config = ServerConfig.new(handler_module: __MODULE__)
      assert config.num_listen_sockets == 1
    end

    test "allows num_listen_sockets less than num_acceptors" do
      config =
        ServerConfig.new(
          handler_module: __MODULE__,
          num_listen_sockets: 3,
          num_acceptors: 10,
          transport_options: [reuseport: true]
        )

      assert config.num_listen_sockets == 3
      assert config.num_acceptors == 10
    end

    test "allows num_listen_sockets equal to num_acceptors" do
      config =
        ServerConfig.new(
          handler_module: __MODULE__,
          num_listen_sockets: 5,
          num_acceptors: 5,
          transport_options: [reuseport: true]
        )

      assert config.num_listen_sockets == 5
      assert config.num_acceptors == 5
    end
  end
end
