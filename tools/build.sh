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
    # Perbaikan konflik versi, HANYA di salinan untuk build (pubspec.yaml di repo tidak diubah):
    # google_mlkit_text_recognition ^0.13.x butuh google_mlkit_commons ^0.8,
    # sedangkan google_mlkit_barcode_scanning ^0.13.0 butuh ^0.9 -> naikkan ke ^0.14.0.
    sed -i -E "s/^([[:space:]]*google_mlkit_text_recognition:[[:space:]]*[\"']?)\^?0\.13\.[0-9]+/\1^0.14.0/" \
      "$APP_DIR/pubspec.yaml" || return 1
    grep -n "google_mlkit" "$APP_DIR/pubspec.yaml" || true
  fi

  # Kompatibilitas AGP 9 untuk plugin lama (mis. flutter_inappwebview_android 1.1.3 yang masih
  # memakai proguard-android.txt). Opt-out resmi dari AGP 9.0 = kembali ke perilaku AGP 8.
  # HANYA di salinan untuk build, file repo tidak diubah.
  {
    echo ""
    echo "# ditambahkan oleh tools/build.sh"
    echo "android.r8.proguardAndroidTxt.disallowed=false"
    echo "android.r8.globalOptionsInConsumerRules.disallowed=false"
    echo "android.proguard.failOnMissingFiles=false"
    echo "android.uniquePackageNames=false"
    echo "android.sourceset.disallowProvider=false"
    echo "android.r8.strictFullModeForKeepRules=false"
    echo "android.r8.optimizedResourceShrinking=false"
  } >> "$APP_DIR/android/gradle.properties" || return 1

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
