defmodule ThousandIsland.ListenerTest do
  use ExUnit.Case, async: true
  use Machete

  alias ThousandIsland.{Listener, ServerConfig}

  # We don't actually implement handler, but we specify it so that our telemetry helpers will work
  @server_config %ServerConfig{port: 4004, handler_module: __MODULE__}

  defmodule TestTransport do
    # This module does not implement all of the callbacks
    # used by the ThousandIsland.Transport behaviour,
    # but contains only the functions required
    # for the Listener to start successfully.

    def listen(port, _options) do
      send(self(), {:test_transport, port})

      :gen_tcp.listen(port,
        mode: :binary,
        active: false
      )
    end

    defdelegate sockname(socket), to: :inet
  end

  describe "init/1" do
    test "returns a :stop tuple if port cannot be bound" do
      # Bind to the port specified in the server config
      # so that it cannot be subsequently bound.
      assert {:ok, socket} = :gen_tcp.listen(@server_config.port, [])

      assert Listener.init(@server_config) == {:stop, :eaddrinuse}

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end

    test "returns an :ok tuple with map containing :listener_socket, :local_info and :listener_span" do
      assert {:ok,
              %{
                listener_socket: socket,
                local_info: {{0, 0, 0, 0}, port},
                listener_span: %ThousandIsland.Telemetry{}
              }} = Listener.init(@server_config)

      assert port == @server_config.port

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end

    test "listens using transport module specified in config" do
      {:ok, %{listener_socket: socket}} =
        Listener.init(%ServerConfig{@server_config | transport_module: TestTransport})

      # 1) Listener.init/1 calls the listen/2 function
      #    in the :transport_module with the :port as an argument
      #    (:transport_module and :port are server config attributes).
      #
      # 2) The listen/2 function in the TestTransport module
      #    sends a {:test_transport, _port} tuple to self() when called.
      #
      # Given (1) and (2), when Listener.init/1 is called
      # we can expect to receive the said tuple.
      assert_receive {:test_transport, port}
      assert @server_config.port == port

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end

    test "listens on port specified in config" do
      # Confirm the port is not bound by asserting
      # that the port can be listened on, then cleanup
      # by closing the socket.
      assert {:ok, socket} = :gen_tcp.listen(@server_config.port, [])
      :gen_tcp.close(socket)

      {:ok, %{listener_socket: socket}} =
        Listener.init(@server_config)

      # Confirm the port is bound by asserting
      # that the port cannot be listened on,
      # as the port is in use.
      assert :gen_tcp.listen(@server_config.port, []) == {:error, :eaddrinuse}

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end

    test "emits expected telemetry event" do
      TelemetryHelpers.attach_all_events(__MODULE__)

      {:ok, %{listener_socket: socket}} = Listener.init(@server_config)

      assert_receive {:telemetry, [:thousand_island, :listener, :start], measurements, metadata},
                     500

      assert measurements ~> %{monotonic_time: integer()}

      assert metadata
             ~> %{
               handler: __MODULE__,
               telemetry_span_context: reference(),
               local_address: {0, 0, 0, 0},
               local_port: @server_config.port,
               transport_module: ThousandIsland.Transports.TCP,
               transport_options: []
             }

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end
  end

  describe "handle_call/3" do
    test "a :listener_info call gives a reply with the :local_info" do
      state = %{local_info: {{0, 0, 0, 0}, 4000}}

      assert Listener.handle_call(:listener_info, nil, state) == {:reply, state.local_info, state}
    end

    test "an :acceptor_info_info call gives a reply with the :listener_socket and :listener_span" do
      {:ok, %{listener_span: span, listener_socket: socket}} =
        Listener.init(@server_config)

      state = %{
        listener_socket: socket,
        listener_span: span
      }

      assert Listener.handle_call(:acceptor_info, nil, state) ==
               {:reply, {state.listener_socket, state.listener_span}, state}

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end
  end

  describe "terminate/2" do
    test "emits telemetry event with expected timings" do
      {:ok, %{listener_span: span, listener_socket: socket}} = Listener.init(@server_config)

      TelemetryHelpers.attach_all_events(__MODULE__)

      Listener.terminate(:normal, %{listener_span: span})

      assert_receive {:telemetry, [:thousand_island, :listener, :stop], measurements, metadata},
                     500

      assert measurements ~> %{monotonic_time: integer(), duration: integer()}

      assert metadata
             ~> %{
               handler: __MODULE__,
               telemetry_span_context: reference(),
               local_address: {0, 0, 0, 0},
               local_port: @server_config.port,
               transport_module: ThousandIsland.Transports.TCP,
               transport_options: []
             }

      # Close the socket to cleanup.
      :gen_tcp.close(socket)
    end
  end
end
