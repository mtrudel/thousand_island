defmodule ThousandIsland.Handler do
  @moduledoc """
  Defines the behaviour required of the application layer of a Thousand Island 
  server. Users pass the name of a module implementing this behaviour as the 
  `handler_module` parameter when starting a server instance, and Thousand Island 
  will call this module's `c:handle_connection/2` function every time a client
  connects to the server.
  """

  @doc """
  Called by Thousand Island once for every client connection. 

  This callback is called from a private process managed by Thousand Island, and has 
  complete and sole control over the given socket. The socket can be written to,
  read from, and otherwise manipulated via the `ThousandIsland.Socket` interface.
  The socket will already have completed handshaking for protocols which require
  such a step (such as SSL). If the socket is not closed within the callback, 
  Thousand Island will ensure that it is properly closed. 

  The second argument consists of an arbitrary term specified via the 
  `handler_options` parameter at server start time.

  The return value of this callback is unused.
  """
  @callback handle_connection(ThousandIsland.Socket.t(), term()) :: term()
end
