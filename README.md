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

A `ConnectionWorker` process manages the entire lifecycle of a client connection (other 
than its initial acceptance by an `Acceptor`), and only lives as long as the 
client is connected. `ConnectionWorker` processes encapsulate the connection state
in a `Connection` struct, passing it to a configured `Handler` module which 
defines the actual implementation of a server at an application level.

This strongly hierarchical approach reduces blocking on connection acceptance, and
also reduces contention for `ConnectionSupervisor` access when creating new 
`ConnectionWorker` processes. It allows each `Acceptor` group to function nearly 
autonomously from one another, with attendant benefits for scalability and crash 
resiliency.

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
connections up to the application level, and forms the primary interface that 
most applications will have with Thousand Island. Thousand Island comes with
a few simple protocol handlers to serve as examples; these can be found in the [handlers](https://github.com/mtrudel/thousand_island) 
folder of the project.

## Transports

The `Transport` behaviour defines the functions required of a transport protocol, 
and is used by the `Listener`, `AcceptorWorker` and `Connection` modules in 
order to interact with underlaying sockets. Currently `Transports.TCP` is the 
only defined transport.

### Draining

TBD on a per-acceptor and per-server basis. 

## What's with the name?

`ThousandIsland` is an alternative to [ranch](https://github.com/ninenines/ranch).

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

