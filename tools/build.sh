#!/usr/bin/env bash
# tools/build.sh
# Build APK Android untuk repo ini (dipanggil oleh .github/workflows/build-apk.yml)
# Hasil akhir: dist/Nexvora.apk
#
# Opsional, taruh di root repo kalau punya aplikasi sendiri:
#   lib/        -> kode Dart aplikasi (lib/main.dart)
#   pubspec.yaml -> dependency + deklarasi assets
#   assets/     -> gambar, font, dll
# Kalau tidak ada, dipakai aplikasi contoh bawaan Flutter.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"
DIST_DIR="$ROOT/dist"
APK_NAME="Nexvora.apk"

cd "$ROOT"

# assets opsional, tapi foldernya harus ada supaya langkah copy tidak gagal
mkdir -p "$ROOT/assets" "$DIST_DIR"

flutter --version

build_apk() {
  # $1 = "shrink" (default) atau "noshrink"
  local mode="${1:-shrink}"
  local flags=(--release)
  if [ "$mode" = "noshrink" ]; then
    flags+=(--no-shrink)
  fi

  rm -rf "$APP_DIR" || return 1
  flutter create --platforms=android --org com.nexora --project-name nexora "$APP_DIR" || return 1

  # Timpa dengan file dari repo (jika ada)
  mkdir -p "$APP_DIR/assets" || return 1
  cp -r "$ROOT/assets/." "$APP_DIR/assets/" || return 1

  if [ -d "$ROOT/lib" ]; then
    rm -rf "$APP_DIR/lib" || return 1
    cp -r "$ROOT/lib" "$APP_DIR/lib" || return 1
  fi
  if [ -f "$ROOT/pubspec.yaml" ]; then
    cp "$ROOT/pubspec.yaml" "$APP_DIR/pubspec.yaml" || return 1
  fi

  ( cd "$APP_DIR" && flutter pub get && flutter build apk "${flags[@]}" ) || return 1

  local apk="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
  if [ ! -f "$apk" ]; then
    echo "Error: APK tidak ditemukan di $apk"
    return 1
  fi
  cp "$apk" "$DIST_DIR/$APK_NAME" || return 1
}

if ! build_apk shrink; then
  echo "Warning: Build gagal, mengulang tanpa pengecilan ukuran."
  build_apk noshrink
fi

ls -lh "$DIST_DIR"