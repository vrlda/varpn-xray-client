#!/usr/bin/env bash
set -euo pipefail

echo "Building VarPN..."

echo "Getting dependencies..."
flutter pub get

echo "Generating code (Riverpod, Freezed, JSON)..."
dart run build_runner build --delete-conflicting-outputs

echo "Build complete! Run 'flutter run' to start the app."
