# VarPN

VarPN is a Flutter VPN client for macOS and iOS. It combines a one-tap connection flow with subscription parsing, automatic node selection, smart routing, and an optional developer mode for diagnostics.

![VarPN](VarPN1.jpg)

## Features

- Import VLESS, VMess, Trojan, and Shadowsocks subscriptions.
- Group nodes by country and select the fastest available node.
- Configure routing, DNS, tunnel, Xray, ping, and subscription settings.
- Run a macOS proxy/utun tunnel backed by Xray-core.
- Run an iOS packet tunnel backed by libXray and Tun2SocksKit.
- Inspect logs, tunnel health, traffic statistics, and recovery state.
- Use Russian or English UI with light, dark, or system theme settings.

## Status

The macOS path is the primary development and release path. The iOS packet-tunnel target builds locally, but real-device testing, Apple signing, and TestFlight validation are still required before distribution.

The non-Apple fallback uses a mock service for UI development. Android and other platforms are not configured in this repository.

## Requirements

- Flutter stable and Dart 3.0 or newer.
- macOS development: Xcode and CocoaPods.
- iOS development: Xcode, CocoaPods, Go, Python 3.12, and `gomobile` for rebuilding libXray.

## Quick start

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d macos
```

`./build.sh` runs dependency installation and Dart code generation together.

## Native dependencies

The repository includes the macOS arm64 Xray executable and GeoIP/GeoSite data under `xray-core/`. The release helper therefore produces an Apple Silicon (`arm64`) macOS build by default. `xray-core/xray.zip` is a local distribution archive and is intentionally ignored.

The iOS `LibXray.xcframework` is intentionally not committed because it is larger than GitHub's 100 MB per-file limit. Rebuild it from the upstream source before opening the iOS project:

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
PYTHON_BIN=/path/to/python3.12 ./scripts/build_libxray_apple.sh
cd ios
pod install
```

The generated framework is placed at `ios/Frameworks/LibXray.xcframework`, which is ignored by Git. See `ios/Frameworks/README.md` for the artifact policy.

## macOS builds

Run the unsigned Apple Silicon release build locally:

```bash
ALLOW_UNSIGNED=1 ./scripts/package_macos_release.sh
```

The script creates `build/dist/VarPN-macos.zip` and `build/dist/VarPN-macos.dmg`. A signed and notarized build requires an Apple Developer account and the appropriate provisioning setup.

Set `MACOS_ARCHS` only when `xray-core/xray` has been replaced with an executable built for the same architecture.

## iOS builds

After rebuilding the framework:

```bash
flutter build ios --simulator --no-codesign
```

For a device archive, use `scripts/archive_ios_release.sh` with a configured Apple team. The app and packet-tunnel extension need matching App Group and Network Extension entitlements.

## Project layout

```text
lib/                    Flutter application and services
test/                   Dart and Flutter tests
ios/                    iOS app and packet-tunnel target
macos/                  macOS app, packet tunnel, and utun helper
xray-core/              Xray executable and routing data
scripts/                Native build and release helpers
.github/workflows/      Continuous integration
```

## Development checks

```bash
flutter analyze --no-fatal-infos
flutter test
```

Generated Dart sources are committed so a fresh clone can build immediately; rerun the build-runner command after changing annotated models or providers.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the local workflow and platform-specific expectations. Release readiness is tracked in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Third-party components

VarPN bundles Xray-core and integrates libXray and Tun2SocksKit. Review the applicable upstream licenses before distributing binaries. Xray-core's license is included at [xray-core/LICENSE](xray-core/LICENSE); libXray is rebuilt from [XTLS/libXray](https://github.com/XTLS/libXray).
