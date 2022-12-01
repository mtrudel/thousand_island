defmodule ThousandIsland.Telemetry do
  @moduledoc false

  use Telemetrex,
    app_name: :thousand_island,
    spans: [
      [
        name: :listener,
        description: "Represents a Thousand Island server listening to a port",
        start_event: [
          metadata: [
            parent_id: "The span ID passed to Thousand Island via the `parent_span_id` option",
            local_address: "The IP address that the listener is bound to",
            local_port: "The port that the listener is bound to",
            transport_module: "The transport module in use",
            transport_opts: "Options passed to the transport module at startup"
          ]
        ]
      ],
      [
        name: :acceptor,
        description: "Represents a Thousand Island acceptor process listening for connections",
        start_event: [
          metadata: [
            parent_id: "The span ID of the `:listener` which created this acceptor"
          ]
        ],
        stop_event: [
          measurements: [
            connections: "The number of client requests that the acceptor handled"
          ]
        ]
      ],
      [
        name: :connection,
        description: "Represents Thousand Island handling a specific client request",
        start_event: [
          metadata: [
            parent_id: "The span ID of the `:acceptor` span which accepted this connection",
            remote_address: "The IP address of the connected client",
            remote_port: "The port of the connected client"
          ]
        ],
        stop_event: [
          measurements: [
            send_oct: "The number of octets sent on the connection",
            send_cnt: "The number of packets sent on the connection",
            recv_oct: "The number of octets received on the connection",
            recv_cnt: "The number of packets received on the connection"
          ]
        ],
        extra_events: [
          [
            name: :ready,
            description: "Thousand Island has completed setting up the client connection"
          ],
          [
            name: :handshake,
            description: "Thousand Island has completed the protocol handshake with the client"
          ],
          [
            name: :handshake_error,
            description: "Thousand Island encountered an error handshaking with the client",
            measurements: [
              error: "A description of the error"
            ]
          ],
          [
            name: :async_recv,
            description: "Thousand Island has asynchronously received data from the client",
            untimed: true,
            measurements: [
              data: "The data received from the client"
            ]
          ],
          [
            name: :recv,
            description: "Thousand Island has synchronously received data from the client",
            untimed: true,
            measurements: [
              data: "The data received from the client"
            ]
          ],
          [
            name: :recv_error,
            description: "Thousand Island encountered an error reading data from the client",
            untimed: true,
            measurements: [
              error: "A description of the error"
            ]
          ],
          [
            name: :send,
            description: "Thousand Island has sent data to the client",
            untimed: true,
            measurements: [
              data: "The data sent to the client"
            ]
          ],
          [
            name: :send_error,
            description: "Thousand Island encountered an error sending data to the client",
            untimed: true,
            measurements: [
              data: "The data that was being sent to the client",
              error: "A description of the error"
            ]
          ],
          [
            name: :sendfile,
            description: "Thousand Island has sent a file to the client",
            untimed: true,
            measurements: [
              filename: "The filename containing data sent to the client",
              offset: "The offset (in bytes) within the file sending started from",
              bytes_written: "The number of bytes written"
            ]
          ],
          [
            name: :sendfile_error,
            description: "Thousand Island encountered an error sending a file to the client",
            untimed: true,
            measurements: [
              filename: "The filename containing data that was being sent to the client",
              offset: "The offset (in bytes) within the file where sending started from",
              length: "The number of bytes that were attempted to send",
              error: "A description of the error"
            ]
          ],
          [
            name: :socket_shutdown,
            description: "Thousand Island has shutdown the client connection",
            measurements: [
              way: "The direction in which the socket was shut down"
            ]
          ]
        ]
      ]
    ]
end
