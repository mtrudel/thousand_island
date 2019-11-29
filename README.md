# 🏝🏝🏝 Thousand Island 🏝🏝🏝 

[![Build Status](https://travis-ci.org/mtrudel/thousand_island.svg?branch=master)](https://travis-ci.org/mtrudel/thousand_island)
[![Hex.pm](https://img.shields.io/hexpm/v/thousand_island.svg?style=flat-square)](https://hex.pm/packages/thousand_island)

[Documentation](https://hexdocs.pm/thousand_island)

Thousand Island is a modern, pure Elixir socket server, inspired heavily by
[ranch](https://github.com/ninenines/ranch). It aims to be easy to understand
& reason about, while also being at least as stable and performant as alternatives. 
Informal tests place ranch and Thousand Island at roughly the same level of 
performance & overhead; short of synthetic scenarios on the busiest of servers, 
they perform equally for all intents and purposes.

Thousand Island is written entirely in Elixir, and is nearly dependency-free (the 
only libary used is [telemetry](https://github.com/beam-telemetry/telemetry)). 
The application strongly embraces OTP design principles, and emphasizes readable, 
simple code. The hope is that as much as Thousand Island is capable of backing 
the most demanding of services, it is also useful as a simple and approachable
reference for idiomatic OTP design patterns.

## Usage

Thousand Island is implemented as a supervision tree which is intended to be hosted
inside a host application, often as a dependency embedded within a higher-level 
protocol library such as [bandit](https://github.com/mtrudel/bandit). Aside from 
supervising the Thousand Island process tree, applications interact with Thousand 
Island primarily via the `ThousandIsland.Handler` behaviour.

### Handlers

The `ThousandIsland.Handler` behaviour defines the interface that Thousand Island 
uses to pass `ThousandIsland.Socket`s up to the application level; together they 
form the primary interface that most applications will have with Thousand Island. 
Thousand Island comes with a few simple protocol handlers to serve as examples; 
these can be found in the [handlers](https://github.com/mtrudel/thousand_island/tree/master/lib/thousand_island/handlers) 
folder of this project. A simple implementation would look like this:

```elixir
defmodule Echo do
  @behaviour ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(%ThousandIsland.Socket{} = socket, _opts) do
    {:ok, req} = ThousandIsland.Socket.recv(socket)
    ThousandIsland.Socket.send(socket, req)
  end
end

{:ok, pid} = ThousandIsland.start_link(port: 1234, handler_module: Echo)
```

This will start a server on TCP port 1234, with each new connection being handled by
a call to `Echo.handle_connection/2`. The implementation above reads in a chunk
of data from the client, echoes it back over the socket, and returns (thus closing 
the connection).

### Starting a Thousand Island Server

Thousand Island servers exist as a supervision tree, and are started by a call
to `ThousandIsland.start_link/1`. There are a number of options supported (for a 
complete description, consult `ThousandIsland.start_link/1`):

* `handler_module`: The name of the module used to handle connections to this server.
The module is expected to implement the `ThousandIsland.Handler` behaviour. Required.
* `handler_options`: A term which is passed as the second argument to all 
`c:ThousandIsland.Handler.handle_connection/2` calls. Optional.
* `port`: The TCP port number to listen on. If not specified this defaults to 4000.
* `transport_module`: The name of the module which provides basic socket functions.
Thousand Island provides `ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL`,
which provide clear and TLS encrypted TCP sockets respectively. If not specified this
defaults to `ThousandIsland.Transports.TCP`.
* `transport_options`: A keyword list of options to be passed to the transport module's
`c:ThousandIsland.Transport.listen/2` function. Valid values depend on the transport
module specified in `transport_module` and can be found in the documentation for the
`ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL` modules.
* `num_acceptors`: The numbner of acceptor processes to run. Defaults to 10.

### Connection Draining & Shutdown

The `ThousandIsland.Server` process is just a standard `Supervisor`, so all the 
usual rules regarding shutdown and shutdown timeouts apply. Immediately upon 
beginning the shutdown sequence the `ThousandIsland.ShutdownListener` will cause 
the listening socket to shut down, which in turn will cause all of the `Acceptor` 
processes to shut down as well. At this point all that is left in the supervision 
tree are several layers of Supervisors and whatever `Connection` processes were 
in progress when shutdown was initiated. At this point, standard Supervisor shutdown
timeout semantics give existing connections a chance to finish things up. `Connection`
processes trap exit, so they continue running beyond shutdown until they either 
complete or are `:brutal_kill`ed after their shutdown timeout expires.

## Implementation Notes

At a top-level, a `Server` coordinates the processes involved in responding to 
connections on a socket. A `Server` manages two top-level processes: a `Listener` 
which is responsible for actually binding to the port and managing the resultant 
listener socket, and an `AcceptorPoolSupervisor` which is responsible for maanging 
a pool of `AcceptorSupervisor` processes.

Each `AcceptorSupervisor` process (there are 10 by default) manages two processes: 
an `Acceptor` which accepts connections made to the server's listener socket, 
and a `DynamicSupervisor` which supervises the processes backing individual
client connections. Every time a client connects to the server's port, one of 
the `Acceptor`s receives the connection in the form of a socket. It then 
creates a new `Connection` process to manage this connection, and immediately 
waits for another connection. It is worth noting that `Acceptor` processes 
are long-lived, and normally live for the entire period that the `Server` is 
running.

A `Connection` process is tied to the lifecycle of a client connection, and 
only lives as long as the client is connected. `Connection` processes
encapsulate the connection state in a `Socket` struct, managing the initial setup 
of the socket, and eventually passing it to a configured `Handler` module 
which defines the application level logic of a server.

This hierarchical approach reduces the time connections spend waiting to be accepted,
and also reduces contention for `DynamicSupervisor` access when creating new 
`Connection` processes. Each `AcceptorSupervisor` subtree functions nearly 
autonomously, improving scalability and crash resiliency.

Graphically, this shakes out like so:

```
             Server (sup, rest_for_one)
             /    \
      Listener    AcceptorPoolSupervisor (dyn_sup)
                    / ....n.... \
                            AcceptorSupervisor (sup, rest_for_one)
                                /      \
                DynamicSupervisor     Acceptor (task)
                  / ....n.... \
                           Connection (task)
```

Thousand Island does not use named processes or other 'global' state internally 
(other than telemetry event names). It is completely supported for a single node
to host any number of `Server` processes each listening on a different port.

## Installation

Thousand Island is [available in Hex](https://hex.pm/docs/publish). The package 
can be installed by adding `thousand_island` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thousand_island, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/thousand_island](https://hexdocs.pm/thousand_island).

## License

MIT

