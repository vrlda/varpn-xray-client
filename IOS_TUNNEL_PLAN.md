# iOS Tunnel Reliability Plan

## Goal

Build an iOS packet-tunnel client that is as reliable as the current macOS client, while staying within iOS extension resource limits.

## Current repo status

- `PacketTunnel` target exists and compiles for iPhone devices.
- `libXray` is embedded as `ios/Frameworks/LibXray.xcframework`.
- `Tun2SocksKit` is integrated for packet forwarding.
- The extension writes shared:
  - `packet-tunnel.log`
  - `traffic-stats.json`
  - `tunnel-health.json`
  - `active-session.json`
- The extension already includes:
  - memory watchdog thresholds
  - extension-side reconnects
  - network-change monitoring
  - traffic and health polling
- Remaining work is now primarily real-device validation and signing/provisioning, not architecture scaffolding.

## Known operational constraint

- iOS app extensions have much tighter memory limits than full apps.
- Apple does not publish a clean `50 MB` guarantee for packet-tunnel extensions, so we should treat `50 MB` as a practical ceiling observed on real devices, not as a contractual system limit.
- `xhttp` is the most likely transport to push the extension over the limit.

## Reliability targets

- The UI must never claim the tunnel is active when the extension is dead.
- The app must reconcile native tunnel state after foregrounding, device unlock, and network changes.
- Unexpected tunnel exits must be logged and surfaced in the app logs.
- The extension must recover automatically whenever recovery is safe.

## iOS tunnel architecture

- Add a dedicated iOS `PacketTunnel` target.
- Keep all shared configuration generation in Dart where possible.
- Use an iOS native bridge for:
  - start
  - stop
  - status query
  - log fetch
  - shared container path

## Memory strategy

### 1. Prevention first

- Keep Xray log level at `warning` or `error` in release.
- Avoid keeping large in-memory debug buffers.
- Keep only one active selected node profile in the extension runtime.
- Prefer aggressive cleanup of temporary files and old logs in the shared container.
- Avoid loading any optional helper data in the extension unless it is required for the active session.

### 2. Memory watchdog inside the extension

- Sample resident memory on a short interval, for example every 2 to 5 seconds.
- Track:
  - current resident memory
  - peak resident memory
  - last reconnect time
  - active transport type
- Log threshold crossings into the shared log file.

### 3. Thresholds

- Soft threshold:
  - around `36-40 MB`
  - action: sync logs, purge temporary data, mark session as high-pressure
- Hard threshold:
  - around `42-46 MB`
  - action: perform a fast reconnect of the active node before the system kills the extension
- Emergency threshold:
  - anything approaching `50 MB`
  - action: immediate controlled reconnect and explicit log entry

## Reconnect policy

- Reconnect only if:
  - the user did not manually stop the VPN
  - the extension still has a valid active node/config
  - a minimum cooldown has elapsed since the last reconnect
- After reconnect:
  - re-query tunnel status from the app
  - restore UI state from native status, not cached Flutter state

## App-side watchdog

- On foreground/resume:
  - query real tunnel status
  - if native tunnel is gone, update UI immediately
  - if tunnel should still be running, request reconnect
- On timer while connected:
  - poll native status periodically
  - sync native logs into app logs

## Release-critical telemetry

- Log:
  - start/stop reason
  - native tunnel state changes
  - Xray exit codes
  - memory threshold crossings
  - watchdog-triggered reconnects
  - network-change-triggered reconnects

## Before TestFlight

- Verify behavior on real iPhones with:
  - `grpc`
  - `xhttp`
  - `reality`
  - sleep/wake
  - Wi-Fi to cellular handoff
  - low-memory background pressure
- Specifically validate that `xhttp` sessions do not silently die near the practical memory ceiling.
