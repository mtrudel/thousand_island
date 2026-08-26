defmodule ThousandIsland.Examples.HTTPHelloWorldTest do
  use ExUnit.Case, async: true

  Code.require_file("../../../examples/http_hello_world.ex", __DIR__)

  test "waits for a complete HTTP/1.0 request across TCP chunks" do
    client = connect()
    assert :ok = :gen_tcp.send(client, "GET / HTTP/1.0\r\nHost: example")
    assert {:error, :timeout} = :gen_tcp.recv(client, 0, 50)
    assert :ok = :gen_tcp.send(client, ".test\r\n\r\n")

    response = receive_all(client)
    assert response =~ "HTTP/1.0 200 OK\r\n"

    assert response =~
             ~r/Date: [A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} GMT\r\n/

    assert response =~ "Content-Type: text/plain; charset=utf-8\r\n"
    assert response =~ "Content-Length: 12\r\n"
    assert String.ends_with?(response, "\r\n\r\nHello, World")
  end

  test "uses a simple response for an HTTP/0.9 simple request" do
    client = connect()
    assert :ok = :gen_tcp.send(client, "GET /\r\n")
    assert receive_all(client) == "Hello, World"
  end

  test "does not include an entity body in a HEAD response" do
    client = connect()
    assert :ok = :gen_tcp.send(client, "HEAD / HTTP/1.0\r\n\r\n")

    response = receive_all(client)
    assert response =~ "HTTP/1.0 200 OK\r\n"
    assert response =~ "Content-Length: 12\r\n"
    assert String.ends_with?(response, "\r\n\r\n")
    refute response =~ "Hello, World"
  end

  test "returns 400 for a malformed request" do
    client = connect()
    assert :ok = :gen_tcp.send(client, "GET\r\n")

    response = receive_all(client)
    assert response =~ "HTTP/1.0 400 Bad Request\r\n"
    assert String.ends_with?(response, "\r\n\r\nBad Request\r\n")
  end

  test "returns 400 for invalid header values and request targets" do
    invalid_requests = [
      "GET / HTTP/1.0\r\nX-Test: a\0b\r\n\r\n",
      "GET not-a-uri HTTP/1.0\r\n\r\n",
      <<"GET /", 0xFF, " HTTP/1.0\r\n\r\n">>,
      "GET /bad%escape HTTP/1.0\r\n\r\n"
    ]

    for request <- invalid_requests do
      client = connect()
      assert :ok = :gen_tcp.send(client, request)
      assert receive_all(client) =~ "HTTP/1.0 400 Bad Request\r\n"
    end
  end

  test "accepts an absolute URI request target" do
    client = connect()
    assert :ok = :gen_tcp.send(client, "GET http://example.test/ HTTP/1.0\r\n\r\n")
    assert receive_all(client) =~ "HTTP/1.0 200 OK\r\n"
  end

  test "returns 501 for an unimplemented method" do
    client = connect()
    assert :ok = :gen_tcp.send(client, "POST / HTTP/1.0\r\nContent-Length: 0\r\n\r\n")

    response = receive_all(client)
    assert response =~ "HTTP/1.0 501 Not Implemented\r\n"
    assert String.ends_with?(response, "\r\n\r\nNot Implemented\r\n")
  end

  defp connect do
    server =
      start_supervised!(
        {ThousandIsland,
         [
           handler_module: HTTPHelloWorld,
           num_acceptors: 1,
           port: 0,
           read_timeout: 1_000
         ]}
      )

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    {:ok, client} = :gen_tcp.connect(:localhost, port, [:binary, active: false])
    client
  end

  defp receive_all(client, acc \\ "") do
    case :gen_tcp.recv(client, 0, 1_000) do
      {:ok, data} -> receive_all(client, acc <> data)
      {:error, :closed} -> acc
    end
  end
end
