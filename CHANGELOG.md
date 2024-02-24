## 1.3.5 (24 Feb 2024)

### Fixes

* Fix regression on non-keyword options (such as `:inet6`) introduced in 1.3.4
  (#113, thanks @danschultzer!)

## 1.3.4 (23 Feb 2024)

### Fixes

* Fix the ability to override default options (and not override hardcoded
  options) for both TCP and SSL transports (#111, thanks @moogle19!)

## 1.3.3 (21 Feb 2024)

### Changes

* Do not set `:linger` as a default option on either TCP or SSL transports. This
  was causing oddball node hangs on larger instances (#110, thanks @jonjon &
  @pojiro!)

## 1.3.2 (31 Dec 2023)

### Changes

* Allow `sni_hosts` or `sni_fun` in place of `cert`/`certfile` and
  `key`/`keyfile`

### Fixes

* Move `handle_info` fallback clause to module compilation hook (#105)

## 1.3.1 (30 Dec 2023)

### Fixes

* Fix downstream dialyzer error introduced by #86

## 1.3.0 (30 Dec 2023)

### Fixes

* Fix issue with eventual acceptor starvation when handling certain network
  conditions (#103)

### Enhancements

* Add check (and logging) for cases where a Handler implementation does not
  return the expected state from GenServer handle_* calls (#96, thanks
  @elfenlaid!)
* Allow protocol upgrades within an active connection (#86, thanks @icehaunter!)

### Changes

* Improve file list for hex packaging (#98, thanks @patrickjaberg and
  @wojtekmach!)

## 1.2.0 (11 Nov 2023)

### Enhancements

* Add `supervisor_options` option to specify top-level supervisor options (#97)

## 1.1.0 (23 Oct 2023)

### Enhancements

* Add support for `silent_terminate_on_error` option to run quietly in case of
  error (#92)

## 1.0.0 (18 Oct 2023)

### Changes

* Do not consider `ECONNABORTED` errors to be exceptional at socket start time
  (#72, thanks @dch!)

## 1.0.0-pre.7 (12 Aug 2023)

### Fixes

* Fix file handle leak when calling `c:Socket.sendfile` (#78)

## 1.0.0-pre.6 (28 Jun 2023)

### Enhancements

* Add support for suspending the acceptance of new requests while continuing to
  process existing ones (#70)

### Changes

* Drop Elixir 1.12 as a supported target (it should continue to work, but is no
  longer covered by CI)

## 1.0.0-pre.5 (16 Jun 2023)

### Changes

* **BREAKING CHANGE** Refactor socket informational functions to mirror the
  underlying `:gen_tcp` and `:ssl` APIs (#76, thanks @asakura!). Details:
    * Add `ThousandIsland.Socket.sockname/1`
    * Add `ThousandIsland.Socket.peername/1`
    * Add `ThousandIsland.Socket.peercert/1`
    * Remove `ThousandIsland.Socket.local_info/1`
    * Remove `ThousandIsland.Socket.peer_info/1`
* Refactor telemetry (#65 thanks @asakura!)

## 1.0.0-pre.4 (13 Jun 2023)

### Enhancements

* Improve typespecs (thanks @asakura!)
* Clean up docs & various internal cleanups (thanks @asakura!)

## 1.0.0-pre.3 (2 Jun 2023)

### Enhancements

* Total overhaul of typespecs throughout the library (thanks @asakura!)
* Internal refactor of several ancillary functions (thanks @asakura!)

## 1.0.0-pre.2 (3 May 2023)

### Enhancements

* Doc improvements

## 1.0.0-pre.1 (19 Apr 2023)

### Changes

* None

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
