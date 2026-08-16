# VarPN

VarPN is a Flutter VPN client for macOS and iOS. It combines a one-tap connection flow with subscription parsing, automatic node selection, smart routing, and practical connection diagnostics.

## Features

- Import VLESS, VMess, Trojan, and Shadowsocks subscriptions.
- Group nodes by country and select the fastest available node.
- Configure routing, DNS, tunnel, Xray, ping, and subscription settings.
- Run a macOS proxy/utun tunnel backed by Xray-core.
- Run an iOS packet tunnel backed by libXray and Tun2SocksKit.
- Inspect logs, tunnel health, traffic statistics, and recovery state.
- Use Russian or English UI with light, dark, or system theme settings.

## Availability

- macOS Apple Silicon: downloadable from the [latest release](https://github.com/vrlda/varpn-xray-client/releases/latest).
- iOS: the project target is included, but distribution still requires Apple signing, real-device testing, and TestFlight validation.
- Android and other platforms are not configured in this repository.

The macOS release is unsigned and not notarized. macOS may require approval in Privacy & Security before opening it.

## Supported protocols

VarPN supports VLESS, VMess, Trojan, and Shadowsocks connection links and subscription feeds.

## Third-party components

VarPN bundles Xray-core and integrates libXray and Tun2SocksKit. Review the applicable upstream licenses before distributing binaries. Xray-core's license is included at [xray-core/LICENSE](xray-core/LICENSE); libXray is maintained by [XTLS/libXray](https://github.com/XTLS/libXray).

## License

VarPN is distributed under the [MIT License](LICENSE).
