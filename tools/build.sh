name: Build APK

on:
  workflow_dispatch:
  push:
    branches: [main]

# Kalau ada push baru ke branch yang sama, batalkan build lama yang masih jalan.
concurrency:
  group: build-apk-${{ github.ref }}
  cancel-in-progress: true

# Workflow ini hanya perlu membaca isi repo.
permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          # Di-pin ke versi yang dipakai di log build kamu, supaya build tidak
          # tiba-tiba berubah saat Flutter merilis stable baru. Naikkan sengaja
          # kalau memang mau upgrade.
          flutter-version: '3.47.7'
          cache: true

      - name: Versi toolchain
        run: |
          flutter --version
          dart --version
          java -version

      # Penyebab build gagal: kode memakai sintaks `.center` (dot-shorthands,
      # fitur Dart 3.10+), tapi batas SDK di pubspec.yaml masih di bawah 3.10,
      # jadi compiler menolaknya walau Flutter di CI sudah baru.
      # Langkah ini menaikkan batas itu di salinan CI saja (tidak di-commit).
      # Solusi permanen: di pubspec.yaml ubah `environment: sdk:` menjadi
      # `^3.10.0`, lalu langkah ini boleh dihapus.
      - name: Aktifkan dot-shorthands (SDK constraint pubspec >= 3.10)
        run: |
          python3 - <<'PY'
          import re
          import subprocess
          from pathlib import Path

          MIN_VERSION = (3, 10, 0)  # dot-shorthands aktif by default mulai Dart 3.10
          NEW_CONSTRAINT = "^3.10.0"


          def version_of(text):
              m = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", text)
              return tuple(int(g or 0) for g in m.groups()) if m else None


          def bump(path):
              lines = path.read_bytes().decode("utf-8").split("\n")
              in_env = False
              for i, line in enumerate(lines):
                  cr = "\r" if line.endswith("\r") else ""
                  body = line[: len(line) - len(cr)]
                  if re.fullmatch(r"environment\s*:\s*(#.*)?", body):
                      in_env = True
                      continue
                  if not in_env:
                      continue
                  if body and not body[0].isspace() and not body.startswith("#"):
                      break  # blok environment sudah selesai
                  m = re.fullmatch(r"(\s+sdk\s*:\s*)(.*?)(\s+#.*)?", body)
                  if not m:
                      continue
                  prefix, comment = m.group(1), m.group(3) or ""
                  value = m.group(2).strip("'\" ")
                  lower = re.search(r"(?:\^|>=)\s*(\d+)\.(\d+)(?:\.(\d+))?", value)
                  if not lower:
                      return f"dilewati, constraint '{value}' tidak dikenali"
                  current = tuple(int(g or 0) for g in lower.groups())
                  if current >= MIN_VERSION:
                      return f"sudah OK ('{value}')"
                  lines[i] = f"{prefix}{NEW_CONSTRAINT}{comment}{cr}"
                  path.write_bytes("\n".join(lines).encode("utf-8"))
                  return f"diubah '{value}' -> '{NEW_CONSTRAINT}'"
              return "dilewati, environment.sdk tidak ditemukan"


          dart = subprocess.run(["dart", "--version"], capture_output=True, text=True)
          installed = version_of(dart.stdout + dart.stderr)
          if installed is None or installed < MIN_VERSION:
              print(f"::warning::Dart terpasang {installed} (< 3.10), pubspec tidak diubah.")
              raise SystemExit(0)

          tracked = subprocess.run(
              ["git", "ls-files", "-z", "--", "*pubspec.yaml"],
              capture_output=True,
              check=True,
          ).stdout.decode("utf-8")
          pubspecs = [Path(f) for f in tracked.split("\0") if f and Path(f).name == "pubspec.yaml"]
          if not pubspecs:
              print("::warning::Tidak ada pubspec.yaml di repo, tidak ada yang diubah.")
          for path in pubspecs:
              print(f"{path}: {bump(path)}")
          PY
          git --no-pager diff -- '*pubspec.yaml'

      - name: Build APK
        run: bash tools/build.sh

      - uses: actions/upload-artifact@v4
        with:
          name: Nexvora-APK
          path: dist/*.apk
          # Gagalkan job kalau APK tidak ditemukan (default-nya hanya warning).
          if-no-files-found: error
