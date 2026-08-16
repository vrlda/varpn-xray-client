# Contributing to VarPN

## Before opening a pull request

1. Run `flutter pub get`.
2. Regenerate Dart sources when changing annotated models or providers:
   `dart run build_runner build --delete-conflicting-outputs`.
3. Run `flutter analyze --no-fatal-infos` and `flutter test`.
4. Keep platform-specific changes scoped to the relevant `ios/` or `macos/` target.
5. Do not commit build output, CocoaPods directories, credentials, subscription URLs, or generated iOS native frameworks.

## Native development

macOS changes can be tested with `flutter run -d macos`. The unsigned packaging helper is:

```bash
ALLOW_UNSIGNED=1 ./scripts/package_macos_release.sh
```

iOS changes require the locally generated `ios/Frameworks/LibXray.xcframework`. See [ios/Frameworks/README.md](ios/Frameworks/README.md). Device and packet-tunnel behavior must be validated on real hardware before release claims are made.

## Pull requests

Describe the user-visible change, platforms tested, and any signing or native prerequisites. Include screenshots for UI changes and call out known limitations or follow-up work.
