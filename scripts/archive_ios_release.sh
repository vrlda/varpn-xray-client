#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/ios/VarPN.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/ios/export}"
WORKSPACE="$ROOT_DIR/ios/Runner.xcworkspace"
SCHEME="Runner"

xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE_PATH" \
  archive

if [[ -n "${EXPORT_OPTIONS_PLIST:-}" ]]; then
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

  echo "Exported iOS release:"
  echo "  $EXPORT_PATH"
else
  echo "Archived iOS release:"
  echo "  $ARCHIVE_PATH"
  echo "Set EXPORT_OPTIONS_PLIST to export an IPA."
fi
