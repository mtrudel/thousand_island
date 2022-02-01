# 🏝🏝🏝 Thousand Island 🏝🏝🏝

[![Build Status](https://github.com/mtrudel/thousand_island/workflows/Elixir%20CI/badge.svg)](https://github.com/mtrudel/thousand_island/actions)
[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/thousand_island)
[![Hex.pm](https://img.shields.io/hexpm/v/thousand_island.svg?style=flat&color=blue)](https://hex.pm/packages/thousand_island)

Thousand Island is a modern, pure Elixir socket server, inspired heavily by
[ranch](https://github.com/ninenines/ranch). It aims to be easy to understand
and reason about, while also being at least as stable and performant as alternatives.
Informal tests place ranch and Thousand Island at roughly the same level of
performance and overhead; short of synthetic scenarios on the busiest of servers,
they perform equally for all intents and purposes.

Thousand Island is written entirely in Elixir, and is nearly dependency-free (the
only library used is [telemetry](https://github.com/beam-telemetry/telemetry)).
The application strongly embraces OTP design principles, and emphasizes readable,
simple code. The hope is that as much as Thousand Island is capable of backing
the most demanding of services, it is also useful as a simple and approachable
reference for idiomatic OTP design patterns.

## Usage

Thousand Island is implemented as a supervision tree which is intended to be hosted
inside a host application, often as a dependency embedded within a higher-level
protocol library such as [Bandit](https://github.com/mtrudel/bandit). Aside from
supervising the Thousand Island process tree, applications interact with Thousand
Island primarily via the `ThousandIsland.Handler` behaviour.

### Handlers

The `ThousandIsland.Handler` behaviour defines the interface that Thousand Island
uses to pass `ThousandIsland.Socket`s up to the application level; together they
form the primary interface that most applications will have with Thousand Island.
Thousand Island comes with a few simple protocol handlers to serve as examples;
these can be found in the [examples](https://github.com/mtrudel/thousand_island/tree/main/examples)
folder of this project. A simple implementation would look like this:

```elixir
defmodule Echo do
  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    ThousandIsland.Socket.send(socket, data)
    {:continue, state}
  end
end

{:ok, pid} = ThousandIsland.start_link(port: 1234, handler_module: Echo)
```

For more information, please consult the `ThousandIsland.Handler` documentation.

### Starting a Thousand Island Server

Thousand Island servers exist as a supervision tree, and are started by a call
to `ThousandIsland.start_link/1`. There are a number of options supported (for a
complete description, consult `ThousandIsland.start_link/1`):

* `handler_module`: The name of the module used to handle connections to this server.
The module is expected to implement the `ThousandIsland.Handler` behaviour. Required.
* `handler_options`: A term which is passed as the initial state value to
`c:ThousandIsland.Handler.handle_connection/2` calls. Optional, defaulting to nil.
* `port`: The TCP port number to listen on. If not specified this defaults to 4000.
* `transport_module`: The name of the module which provides basic socket functions.
Thousand Island provides `ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL`,
which provide clear and TLS encrypted TCP sockets respectively. If not specified this
defaults to `ThousandIsland.Transports.TCP`.
* `transport_options`: A keyword list of options to be passed to the transport module's
`c:ThousandIsland.Transport.listen/2` function. Valid values depend on the transport
module specified in `transport_module` and can be found in the documentation for the
`ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL` modules.
* `num_acceptors`: The number of acceptor processes to run. Defaults to 10.

### Connection Draining & Shutdown

The `ThousandIsland.Server` process is just a standard `Supervisor`, so all the
usual rules regarding shutdown and shutdown timeouts apply. Immediately upon
beginning the shutdown sequence the `ThousandIsland.ShutdownListener` will cause
the listening socket to shut down, which in turn will cause all of the `Acceptor`
processes to shut down as well. At this point all that is left in the supervision
tree are several layers of Supervisors and whatever `Handler` processes were
in progress when shutdown was initiated. At this point, standard Supervisor shutdown
timeout semantics give existing connections a chance to finish things up. `Handler`
processes trap exit, so they continue running beyond shutdown until they either
complete or are `:brutal_kill`ed after their shutdown timeout expires.

## Implementation Notes

At a top-level, a `Server` coordinates the processes involved in responding to
connections on a socket. A `Server` manages two top-level processes: a `Listener`
which is responsible for actually binding to the port and managing the resultant
listener socket, and an `AcceptorPoolSupervisor` which is responsible for managing
a pool of `AcceptorSupervisor` processes.

Each `AcceptorSupervisor` process (there are 10 by default) manages two processes:
an `Acceptor` which accepts connections made to the server's listener socket,
and a `DynamicSupervisor` which supervises the processes backing individual
client connections. Every time a client connects to the server's port, one of
the `Acceptor`s receives the connection in the form of a socket. It then creates
a new process based on the configured handler to manage this connection, and
immediately waits for another connection. It is worth noting that `Acceptor`
processes are long-lived, and normally live for the entire period that the
`Server` is running.

A handler process is tied to the lifecycle of a client connection, and is
only started when a client connects. The length of its lifetime beyond that of the
underlying connection is dependent on the behaviour of the configured Handler module.
In typical cases its lifetime is directly related to that of the underlying connection.

This hierarchical approach reduces the time connections spend waiting to be accepted,
and also reduces contention for `DynamicSupervisor` access when creating new
`Handler` processes. Each `AcceptorSupervisor` subtree functions nearly
autonomously, improving scalability and crash resiliency.

Graphically, this shakes out like so:

```
                        Server (sup, rest_for_one)
              ____________/        |          \___________________
             /                     |                              \
      Listener         AcceptorPoolSupervisor (dyn_sup)      ShutdownListener
                             / ....n.... \
                 AcceptorSupervisor (sup, rest_for_one)
                            /      \
              Acceptor (task)     DynamicSupervisor
                                    / ....n.... \
                                 Handler (gen_server)
```

Thousand Island does not use named processes or other 'global' state internally
(other than telemetry event names). It is completely supported for a single node
to host any number of `Server` processes each listening on a different port.

## Contributing

Contributions to Thousand Island are very much welcome! Before undertaking any substantial work, please
open an issue on the project to discuss ideas and planned approaches so we can ensure we keep
progress moving in the same direction.

All contributors must agree and adhere to the project's [Code of
Conduct](https://github.com/mtrudel/thousand_island/blob/main/CODE_OF_CONDUCT.md).

Security disclosures should be sent privately to mat@geeky.net.

## Installation

Thousand Island is [available in Hex](https://hex.pm/packages/thousand_island). The package
can be installed by adding `thousand_island` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thousand_island, "~> 0.5.2"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/thousand_island](https://hexdocs.pm/thousand_island).

## License

MIT

