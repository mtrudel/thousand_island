# Changelog for 0.6.x

## 0.6.7 (9 Apr 2023)

### Changes

* Thousand Island now sets its `id` field in its spec to be `{ThousandIsland, ref()}`
* `num_connections` defaults to 16384 connections per acceptor 

### Enhancements

* Doc improvements

## 0.6.6 (7 Apr 2023)

### Enhancements

* Added `num_connections` parameter to specify the max number of concurrent
  connections allowed per acceptor
* Added `max_connections_retry_count` and `max_connections_retry_wait`
  parameters to configure how Thousand Island behaves when max connections are
  reached
* Added `[:thousand_island, :acceptor, :spawn_error]` telemetry event to track
  when max connections are reached
* Added max connection logging as part of the
  `ThousandIsland.Logger.attach_logger(:error)` level

### Changes

* Refactored connection startup logic to move some burden from acceptor to
  connection process

## 0.6.5 (27 Mar 2023)

### Changes

* Handshake errors no longer loudly crash the handler process
* `handle_error/3` documentation updated to explicitly mention handshake errors

## 0.6.4 (17 Mar 2023)

### Changes

* Modified telemetry event payloads to match the conventions espoused by
  `:telemetry.span/3`

## 0.6.3 (14 Mar 2023)

### Enhancements

* Added `shutdown_timeout` configuration parameter to configure how long to wait
  for existing connections to shutdown before forcibly killing them at shutdown

### Changes

* Default value for `num_acceptors` is now 100
* Default value for `read_timeout` is now 60000 ms

### Fixes

* Added missing documentation for read_timeout configuration parameter

## 0.6.2 (22 Feb 2023)

### Fixes

* Fixes a race condition at application shutdown that caused spurious acceptor
  crashes to litter the logs (#44). Thanks @danschultzer!


## 0.6.1 (19 Feb 2023)

### Changes

* Expose ThousandIsland.Telemetry.t() as a transparent type
* Pass telemetry errors in metadata rather than metrics
* Allow explicit passing of start times into telemetry spans

## 0.6.0 (4 Feb 2023)

### Enhancements

* (Re)introduce telemetry support as specified in the `ThousandIsland.Telemetry`
  module

# Changelog for 0.5.x

## 0.5.17 (31 Jan 2023)

### Enhancements

* Add `ThousandIsland.connection_pids/1` to enumerate connection processes

## 0.5.16 (21 Jan 2023)

### Enhancements

* Narrow internal pattern matches to enable Handlers to use their own socket calls (#39)

### Fixes

* Fix documentation typos

## 0.5.15 (10 Jan 2023)

### Enhancements

* Do not emit GenServer crash logs in connection timeout situations
* Doc updates
