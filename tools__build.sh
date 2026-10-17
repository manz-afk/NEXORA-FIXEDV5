#!/usr/bin/env bash
# Membuat project Android lengkap + build APK Nexvora
# Kalau widget layar utama bikin build gagal: NO_WIDGET=1 bash tools/build.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/pubspec.yaml" ] || { echo "::error::pubspec.yaml tidak ditemukan di $ROOT"; exit 1; }
# Default: tanpa widget (plugin home_widget bikin compileReleaseKotlin gagal). Aktifkan lagi: NO_WIDGET=0
export NO_WIDGET="${NO_WIDGET:-1}"
WORK="$ROOT/.work"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"

flutter create --org com.nexvora --project-name nexvora --platforms android app
cd app
rm -rf lib test
cp -r "$ROOT/lib" lib
cp -r "$ROOT/assets" assets
cp "$ROOT/pubspec.yaml" pubspec.yaml
pip install pillow >/dev/null 2>&1 || true
python3 - <<'PY'
from PIL import Image
import os
im = Image.open("assets/logo.png").convert("RGBA")
for n, sz in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)]:
    d = "android/app/src/main/res/mipmap-" + n
    os.makedirs(d, exist_ok=True)
    im.resize((sz, sz), Image.LANCZOS).save(d + "/ic_launcher.png")
PY
if [ "$NO_WIDGET" = "1" ]; then
  # buang plugin home_widget dari pubspec + ganti widget_sync dengan stub kosong
  sed -i '/home_widget:/d' pubspec.yaml
  printf 'Future<void> syncWidget() async {}\n' > lib/core/widget_sync.dart
fi
python3 "$ROOT/tools/patch_android.py" android

flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings || true
flutter build apk --release

mkdir -p "$ROOT/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/dist/Nexvora.apk"
echo "SELESAI -> dist/Nexvora.apk"
