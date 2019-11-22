# 1k🏝 

Thousand Island is a pure Elixir socket server, inspired heavily by [ranch](https://github.com/ninenines/ranch).

## Architecture

At a top-level, a `Server` coordinates the processes involved
in responding to connections on a socket. A `Server` manages two top-level
processes: a `Listener` which is responsible for actually binding to the port 
and managing the resultant listener socket, and an `AcceptorSupervisor` which 
is responsible for maanging a pool of `Acceptor` processes. 

Each `Acceptor` process (there are 10 by default) manages two processes: an 
`AcceptorWorker` which accepts connections made to the server's listener socket, 
and a `ConnectionSupervisor` which supervises the processes backing individual
client connections. Every time a client connects to the server's port, one of 
the `AcceptorWorkers` receives the connection in the form of a socket. It then 
creates a new `ConnectionWorker` process to manage this connection, and immediately 
waits for another connection. It is worth noting that `AcceptorWorker` processes 
are long-lived, and normally live for the entire period that the `Server` is 
running.

A `ConnectionWorker` process is tied to the lifecycle of a client connection, and 
only lives as long as the client is connected. `ConnectionWorker` processes
encapsulate the connection state in a `Socket` struct, passing it to a 
configured `Handler` module which defines the application level logic of a server.

This hierarchical approach reduces the time connections spend waiting to be accepted,
and also reduces contention for `ConnectionSupervisor` access when creating new 
`ConnectionWorker` processes. Each `Acceptor` group functions nearly autonomously, 
improving scalability and crash resiliency.

Graphically, this shakes out like so:

```
             Server (sup, rest_for_one)
             /    \
      Listener    AcceptorSupervisor (sup, one_for_one)
                    / ....n.... \
                                Acceptor (sup, rest_for_one)
                                /      \
    (dyn_sup) ConnectionSupervisor     AcceptorWorker (task)
                / ....n.... \
                      ConnectionWorker (task)
```

## Handlers

The `Handler` behaviour defines the interface that Thousand Island uses to pass
`Socket`s up to the application level; together they form the primary interface that 
most applications will have with Thousand Island. Thousand Island comes with
a few simple protocol handlers to serve as examples; these can be found in the [handlers](https://github.com/mtrudel/thousand_island/tree/master/lib/thousand_island/handlers) 
folder of this project.

## Transports

The `Transport` behaviour defines the functions required of a transport protocol, and is used by the `Listener`,
`AcceptorWorker` and `Socket` modules in order to interact with underlaying sockets. Currently
`ThousandIsland.Transports.TCP` and `ThousandIsland.Transports.SSL` are defined.

### Using SSL

To use `ThousandIsland.Transports.SSL`, you'll need to set the key and certificate to use 
via `transport_options`, like so:

```
ThousandIsland.Server.start_link(
  transport_module: ThousandIsland.Transports.SSL, 
  transport_options: [certfile: "certificate.pem", keyfile: "key.pem"], 
  handler_module: MyHandler,
  handler_options, [...]
)
```

### Draining

TBD on a per-acceptor and per-server basis. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `thousand_island` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thousand_island, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/thousand_island](https://hexdocs.pm/thousand_island).

