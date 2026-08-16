#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/macos_release_derived}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/build/dist}"
DMG_STAGE_DIR="${DMG_STAGE_DIR:-$ROOT_DIR/build/dmg_stage}"
APP_NAME="VarPN.app"
WORKSPACE="$ROOT_DIR/macos/Runner.xcworkspace"
SCHEME="Runner"
MACOS_ARCHS="${MACOS_ARCHS:-arm64}"
HELPER_BUILD_SCRIPT="$ROOT_DIR/scripts/build_macos_utun_helper.sh"
HELPER_PLIST="$ROOT_DIR/macos/UtunHelper/cc.varpn.easyxray.utun-helper.plist"
HELPER_RESOURCE_DIR_NAME="UtunHelper"

mkdir -p "$DIST_DIR"

BUILD_ARGS=(
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration Release
  -derivedDataPath "$DERIVED_DATA_PATH"
)

if [[ "${ALLOW_UNSIGNED:-0}" == "1" ]]; then
  BUILD_ARGS+=("CODE_SIGNING_ALLOWED=NO")
fi

# The bundled Xray executable is currently arm64-only. Override this only when
# xray-core/xray has been replaced with a matching executable.
BUILD_ARGS+=("ARCHS=$MACOS_ARCHS" "ONLY_ACTIVE_ARCH=YES")
BUILD_ARGS+=(build)

xcodebuild "${BUILD_ARGS[@]}"

HELPER_PATH="$("$HELPER_BUILD_SCRIPT" | tail -n 1)"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"
ZIP_PATH="$DIST_DIR/VarPN-macos.zip"
DMG_PATH="$DIST_DIR/VarPN-macos.dmg"
HELPER_RESOURCE_DIR="$APP_PATH/Contents/Resources/$HELPER_RESOURCE_DIR_NAME"

rm -rf "$APP_PATH/Contents/PlugIns/PacketTunnel.appex"

mkdir -p "$HELPER_RESOURCE_DIR"
cp "$HELPER_PATH" "$HELPER_RESOURCE_DIR/varpn-utun-helper"
chmod +x "$HELPER_RESOURCE_DIR/varpn-utun-helper"
cp "$HELPER_PLIST" "$HELPER_RESOURCE_DIR/cc.varpn.easyxray.utun-helper.plist"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
cp -R "$APP_PATH" "$DMG_STAGE_DIR/$APP_NAME"
ln -sfn /Applications "$DMG_STAGE_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "VarPN" -srcfolder "$DMG_STAGE_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "Packaged macOS release:"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
