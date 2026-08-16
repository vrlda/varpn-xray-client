#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/macos/UtunHelper"
SCRATCH_PATH="${SCRATCH_PATH:-$ROOT_DIR/build/macos_utun_helper}"
PRODUCT_NAME="VarPNUtunHelper"

swift build \
  --package-path "$PACKAGE_DIR" \
  --scratch-path "$SCRATCH_PATH" \
  -c release \
  --product "$PRODUCT_NAME"

echo "$SCRATCH_PATH/release/$PRODUCT_NAME"
