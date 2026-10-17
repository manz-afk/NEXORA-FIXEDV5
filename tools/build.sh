#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$ROOT/pubspec.yaml" ]; then
  echo "::error::pubspec.yaml tidak ditemukan di $ROOT"
  exit 1
fi

# NO_WIDGET=1 menonaktifkan widget layar utama (bisa bikin build gagal)
export NO_WIDGET="${NO_WIDGET:-1}"

WORK="$ROOT/.work"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

flutter create --org com.nexvora --project-name nexvora --platforms android app

cd app
rm -rf lib test
cp -r "$ROOT/lib" lib
cp -r "$ROOT/assets" assets
cp "$ROOT/pubspec.yaml" pubspec.yaml

pip install pillow >/dev/null 2>&1 || pip install --break-system-packages pillow >/dev/null 2>&1 || true

# Ikon launcher dari assets/logo.png
python3 - <<'PY'
from PIL import Image
import os

src = Image.open("assets/logo.png").convert("RGBA")
sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
for folder, px in sizes.items():
    d = os.path.join("android", "app", "src", "main", "res", folder)
    os.makedirs(d, exist_ok=True)
    src.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))
print("ikon dibuat")
PY

if [ "$NO_WIDGET" = "1" ]; then
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