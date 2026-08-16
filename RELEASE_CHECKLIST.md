# Release Checklist

## Public repository

- Choose and add a license for VarPN source code before publishing the repository.
- Keep third-party notices for Xray-core, libXray, and Tun2SocksKit with the release materials.
- Enable the CI workflow as a required check after creating the GitHub repository.

## macOS

- App bundle identifier set to `cc.varpn.easyxray`
- Proxy-backed macOS runtime is the active shipping path for free-account builds
- Xray core bundled into the macOS app target
- Release build verified locally with:
  - `flutter test`
  - `xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release -derivedDataPath /tmp/easyxray_release_build CODE_SIGNING_ALLOWED=NO build`

## macOS still required before distribution

- Build a signed Release app if a paid Apple Developer account becomes available
- Notarize the `.app` if a paid Apple Developer account becomes available
- Package as a user-friendly `.dmg` or `.zip`
- Repository helper: `scripts/package_macos_release.sh`
- Replace any remaining development-only descriptions with final product branding

## iOS current state

- Flutter iOS platform project added with bundle identifier `cc.varpn.easyxray`
- iOS packet tunnel target is wired into the Xcode project with:
  - bundle identifier `cc.varpn.easyxray.PacketTunnelProvider`
  - app group `group.cc.varpn.easyxray`
  - packet tunnel entitlements on both app and extension targets
- Real `libXray` runtime is embedded through `ios/Frameworks/LibXray.xcframework`
- Real `Tun2SocksKit` packet forwarding is integrated in the iOS extension
- iOS native bridge now supports:
  - `startTunnel`
  - `stopTunnel`
  - `tunnelStatus`
  - `sharedContainerPath`
  - `nativeLogEntries`
  - `clearNativeLogs`
  - `trafficStats`
  - `tunnelHealth`
  - `measureLatency`
- iOS extension now writes shared snapshots for:
  - native tunnel logs
  - traffic stats
  - tunnel health
  - active session recovery metadata
- iOS extension includes:
  - memory watchdog with soft / hard / emergency thresholds
  - extension-side reconnect logic
  - network-change recovery
- iOS app target builds locally with:
  - `flutter build ios --simulator --no-codesign`
  - `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

## iOS work required next

- Run `ruby scripts/setup_ios_packet_tunnel_target.rb` if the project file needs to be regenerated
- Sign the app + packet tunnel with a real Apple team for on-device installation
- Validate the full runtime on real iPhones:
  - `grpc`
  - `xhttp`
  - mixed subscriptions
  - foreground/background and lock/unlock
  - Wi-Fi / cellular / network regain flows
- Verify extension memory behavior on real devices, especially with `xhttp`
- Confirm extension-side reconnect before iOS kills the tunnel under pressure
- Repository helper: `scripts/archive_ios_release.sh`
- Run TestFlight smoke testing before any wider distribution
