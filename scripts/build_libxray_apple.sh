#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-/tmp/varpn_libxray_build}"
LIBXRAY_DIR="$WORK_DIR/libXray"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Missing Python interpreter: $PYTHON_BIN" >&2
  exit 1
fi

command -v go >/dev/null 2>&1 || {
  echo "Go is required to build libXray." >&2
  exit 1
}

mkdir -p "$WORK_DIR"
if [[ ! -d "$LIBXRAY_DIR/.git" ]]; then
  git clone --depth=1 https://github.com/XTLS/libXray "$LIBXRAY_DIR"
else
  git -C "$LIBXRAY_DIR" fetch --depth=1 origin main
  git -C "$LIBXRAY_DIR" reset --hard FETCH_HEAD
fi

export PATH="$(go env GOPATH)/bin:$PATH"

if ! command -v gomobile >/dev/null 2>&1; then
  echo "gomobile is required. Install it with: go install golang.org/x/mobile/cmd/gomobile@latest" >&2
  exit 1
fi

pushd "$LIBXRAY_DIR" >/dev/null
"$PYTHON_BIN" build/main.py apple gomobile
popd >/dev/null

mkdir -p "$ROOT_DIR/ios/Frameworks"
rm -rf "$ROOT_DIR/ios/Frameworks/LibXray.xcframework"
ditto "$LIBXRAY_DIR/LibXray.xcframework" "$ROOT_DIR/ios/Frameworks/LibXray.xcframework"

echo "Bundled framework updated:"
echo "  $ROOT_DIR/ios/Frameworks/LibXray.xcframework"
