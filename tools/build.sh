#!/usr/bin/env bash
# Build APK release dan salin ke dist/
set -euo pipefail

cd "$(dirname "$0")/.."

flutter pub get
flutter build apk --release

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/Nexvora.apk

ls -lh dist/