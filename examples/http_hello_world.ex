defmodule HTTPHelloWorld do
  @moduledoc """
  A small HTTP/1.0 origin server example implementing a conservative subset of
  RFC 1945.

  It implements `GET` and `HEAD`, recognizes HTTP/0.9 simple requests, waits for
  a complete request before responding, and closes each connection after one
  response. Start it with the default handler options so the initial request
  buffer is `[]`.
  """

  use ThousandIsland.Handler

  @body "Hello, World"
  @max_request_size 16_384
  @separators ~c"()<>@,;:\\\"/[]?={} \t"
  @uri_characters ~c"$-_.+!*'(),;/?:@&="

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    request = IO.iodata_to_binary([state, data])

    case parse_request(request) do
      :more ->
        {:continue, request}

      {:simple, :get} ->
        ThousandIsland.Socket.send(socket, @body)
        {:close, request}

      {:full, :get} ->
        ThousandIsland.Socket.send(socket, response("200 OK", @body, true))
        {:close, request}

      {:full, :head} ->
        ThousandIsland.Socket.send(socket, response("200 OK", @body, false))
        {:close, request}

      {:error, :not_implemented} ->
        body = "Not Implemented\r\n"
        ThousandIsland.Socket.send(socket, response("501 Not Implemented", body, true))
        {:close, request}

      {:error, :bad_request} ->
        body = "Bad Request\r\n"
        ThousandIsland.Socket.send(socket, response("400 Bad Request", body, true))
        {:close, request}
    end
  end

  defp parse_request(request) when byte_size(request) > @max_request_size,
    do: {:error, :bad_request}

  defp parse_request(request) do
    case :binary.match(request, "\r\n") do
      :nomatch ->
        :more

      {line_end, 2} ->
        request_line = binary_part(request, 0, line_end)
        parse_request_line(request_line, request, line_end)
    end
  end

  defp parse_request_line(request_line, request, line_end) do
    case request_line |> String.split(" ", trim: true) do
      ["GET", target] ->
        if valid_target?(target), do: {:simple, :get}, else: {:error, :bad_request}

      [_method, _target] ->
        {:error, :bad_request}

      [method, target, "HTTP/1.0"] ->
        parse_full_request(method, target, request, line_end)

      [_method, _target, "HTTP/" <> _version] ->
        {:error, :bad_request}

      _ ->
        {:error, :bad_request}
    end
  end

  defp parse_full_request(method, target, request, line_end) do
    with true <- valid_token?(method),
         true <- valid_target?(target),
         {:ok, headers} <- complete_headers(request, line_end),
         true <- valid_headers?(headers) do
      case method do
        "GET" -> {:full, :get}
        "HEAD" -> {:full, :head}
        _ -> {:error, :not_implemented}
      end
    else
      :more -> :more
      _ -> {:error, :bad_request}
    end
  end

  defp complete_headers(request, line_end) do
    case :binary.match(request, "\r\n\r\n") do
      :nomatch ->
        :more

      {^line_end, 4} ->
        {:ok, ""}

      {headers_end, 4} ->
        headers_start = line_end + 2
        {:ok, binary_part(request, headers_start, headers_end - headers_start)}
    end
  end

  defp valid_headers?(""), do: true

  defp valid_headers?(headers) do
    headers
    |> :binary.split("\r\n", [:global])
    |> Enum.reduce_while(false, fn line, previous_header? ->
      cond do
        valid_continuation?(line) and previous_header? ->
          {:cont, true}

        valid_header?(line) ->
          {:cont, true}

        true ->
          {:halt, false}
      end
    end)
  end

  defp valid_continuation?(<<char, value::binary>>) when char in [32, 9],
    do: valid_field_value?(value)

  defp valid_continuation?(_line), do: false

  defp valid_header?(line) do
    case :binary.split(line, ":") do
      [name, value] -> valid_token?(name) and valid_field_value?(value)
      _ -> false
    end
  end

  defp valid_field_value?(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.all?(fn char -> char == 9 or (char >= 32 and char != 127) end)
  end

  defp valid_token?(value) when byte_size(value) > 0 do
    value
    |> :binary.bin_to_list()
    |> Enum.all?(fn char -> char > 31 and char < 127 and char not in @separators end)
  end

  defp valid_token?(_value), do: false

  defp valid_target?(<<"/", _::binary>> = target), do: valid_uri_characters?(target)

  defp valid_target?(target) when byte_size(target) > 0 do
    case :binary.split(target, ":") do
      [scheme, rest] -> valid_scheme?(scheme) and valid_uri_characters?(rest)
      _ -> false
    end
  end

  defp valid_target?(_target), do: false

  defp valid_scheme?(scheme) when byte_size(scheme) > 0 do
    scheme
    |> :binary.bin_to_list()
    |> Enum.all?(fn char ->
      (char >= ?A and char <= ?Z) or (char >= ?a and char <= ?z) or
        (char >= ?0 and char <= ?9) or char in ~c"+-."
    end)
  end

  defp valid_scheme?(_scheme), do: false

  defp valid_uri_characters?(<<>>), do: true

  defp valid_uri_characters?(<<"%", high, low, rest::binary>>) do
    hex_digit?(high) and hex_digit?(low) and valid_uri_characters?(rest)
  end

  defp valid_uri_characters?(<<char, rest::binary>>) do
    valid_uri_character?(char) and valid_uri_characters?(rest)
  end

  defp valid_uri_character?(char) do
    (char >= ?A and char <= ?Z) or (char >= ?a and char <= ?z) or
      (char >= ?0 and char <= ?9) or char in @uri_characters
  end

  defp hex_digit?(char),
    do:
      (char >= ?0 and char <= ?9) or (char >= ?A and char <= ?F) or
        (char >= ?a and char <= ?f)

  defp response(status, body, include_body?) do
    headers = [
      "HTTP/1.0 ",
      status,
      "\r\n",
      "Date: ",
      Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S GMT"),
      "\r\n",
      "Content-Type: text/plain; charset=utf-8\r\n",
      "Content-Length: ",
      Integer.to_string(byte_size(body)),
      "\r\n\r\n"
    ]

    if include_body?, do: [headers, body], else: headers
  end
end
