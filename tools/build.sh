#!/usr/bin/env bash
# =============================================================================
# NEXVORA - tools/build.sh                                   (revisi perbaikan)
# Build APK release untuk CI (GitHub Actions) maupun lokal.
#
# ISI FILE INI HARUS SHELL MURNI.
# JANGAN menempel YAML workflow ("- uses:", "with:", "run:", "- name:") di sini.
# Itulah penyebab "command not found" + "syntax error near unexpected token '('"
# (exit code 2). Setup Java/Flutter tempatnya di .github/workflows/*.yaml.
#
# Pemakaian : bash tools/build.sh [argumen tambahan untuk "flutter build apk"]
# Env opsi  : APP_ORG=com.contoh  hanya dipakai bila android/ harus dibuat ulang
#             NO_SHRINK=1         lewati R8 (APK lebih besar, tapi pasti lolos R8)
# =============================================================================
set -Eeuo pipefail
trap 'rc=$?; echo "ERROR: tools/build.sh gagal (exit ${rc}) di baris ${LINENO}" >&2' ERR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log()  { printf '\n==> %s\n' "$*"; }
warn() {
  printf 'WARN: %s\n' "$*" >&2
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then printf '::warning::%s\n' "$*"; fi
}
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -f pubspec.yaml ]] || die "pubspec.yaml tidak ditemukan di ${ROOT}"
APP_NAME="$(awk '/^name:/ {v=$2; gsub(/["\047\r]/, "", v); print v; exit}' pubspec.yaml)"
[[ -n "$APP_NAME" ]] || die "Tidak bisa membaca 'name:' dari pubspec.yaml"

# -----------------------------------------------------------------------------
# 1. Versi toolchain
# -----------------------------------------------------------------------------
log "1/9 Versi toolchain"
flutter --version
dart --version
java -version

# -----------------------------------------------------------------------------
# 2. Pulihkan berkas "rata": lib__core__api.dart -> lib/core/api.dart
#    Aman: tidak menimpa berkas yang sudah ada; no-op bila lib/ sudah lengkap.
# -----------------------------------------------------------------------------
restore_flat_files() {
  local f dest copied=0
  shopt -s nullglob
  for f in lib__* tools__*; do
    [[ -f "$f" ]] || continue
    dest="${f//__//}"
    if [[ -e "$dest" ]]; then
      cmp -s -- "$f" "$dest" || warn "BERBEDA: ${f} vs ${dest} (yang dipakai: ${dest})"
      continue
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    cp -- "$f" "$dest"
    copied=$((copied + 1))
  done
  shopt -u nullglob
  echo "restore_flat_files: ${copied} berkas dipulihkan ke struktur folder"
}
log "2/9 Pulihkan struktur folder"
restore_flat_files

# -----------------------------------------------------------------------------
# 3. Guard ERROR-03: Target file "lib/main.dart" not found
# -----------------------------------------------------------------------------
log "3/9 Cek lib/main.dart"
[[ -f lib/main.dart ]] || die 'Target file "lib/main.dart" tidak ada. Pindahkan lib__main.dart ke lib/main.dart.'
echo "OK: lib/main.dart ada"

# -----------------------------------------------------------------------------
# 4. Bahasa Dart >= 3.10 (dot-shorthands: .new, .center, dst.)
#    Versi bahasa mengikuti BATAS BAWAH environment.sdk di pubspec.yaml.
# -----------------------------------------------------------------------------
check_dart_sdk_constraint() {
  local line major minor re='([0-9]+)\.([0-9]+)'
  line="$(awk '/^environment:/ {e=1; next} e && /^[^[:space:]#]/ {e=0} e && /^[[:space:]]+sdk:/ {print; exit}' pubspec.yaml || true)"
  if [[ -z "$line" ]]; then
    warn "environment.sdk tidak ditemukan di pubspec.yaml"
    return 0
  fi
  line="${line#"${line%%[![:space:]]*}"}"   # buang spasi di depan
  if [[ "$line" =~ $re ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    if (( major * 100 + minor < 310 )); then
      warn "pubspec.yaml '${line}': batas bawah SDK < 3.10. Dot-shorthands butuh minimal sdk: ^3.10.0"
    else
      echo "OK: ${line} (>= 3.10)"
    fi
  fi
}
log "4/9 Cek SDK constraint pubspec"
check_dart_sdk_constraint

# -----------------------------------------------------------------------------
# 5. Scaffold android/ (repo tidak menyimpan folder android/)
# -----------------------------------------------------------------------------
ensure_android_scaffold() {
  local org_args=()
  if [[ -d android/app ]]; then
    echo "android/ sudah ada"
    return 0
  fi
  if [[ -n "${APP_ORG:-}" ]]; then org_args=(--org "$APP_ORG"); fi
  warn "android/ tidak ada: flutter create --platforms=android (nama=${APP_NAME}). applicationId mengikuti default Flutter kecuali APP_ORG diisi."
  flutter create --platforms=android ${org_args[@]+"${org_args[@]}"} --project-name "$APP_NAME" .
}
log "5/9 Scaffold Android"
ensure_android_scaffold

# -----------------------------------------------------------------------------
# 6. Patch Android milik repo (bila ada)
# -----------------------------------------------------------------------------
log "6/9 Patch Android"
if [[ -f tools/patch_android.py ]]; then
  python3 tools/patch_android.py
else
  warn "tools/patch_android.py tidak ada: langkah patch dilewati"
fi

# -----------------------------------------------------------------------------
# 7. Dependensi
# -----------------------------------------------------------------------------
log "7/9 flutter pub get"
flutter pub get

# -----------------------------------------------------------------------------
# 8. Guard ERROR-04: AGP 9 menolak getDefaultProguardFile('proguard-android.txt')
#    (flutter_inappwebview_android 1.1.3 dan plugin lain). Diganti ke
#    proguard-android-optimize.txt pada salinan pub-cache di runner (idempoten).
# -----------------------------------------------------------------------------
patch_pub_cache_agp9() {
  local cache="${PUB_CACHE:-$HOME/.pub-cache}" f n=0
  if [[ ! -d "$cache/hosted" ]]; then
    warn "pub-cache tidak ditemukan di ${cache}: patch AGP 9 dilewati"
    return 0
  fi
  while IFS= read -r -d '' f; do
    if grep -q 'proguard-android\.txt' "$f"; then
      sed -i.bak 's/proguard-android\.txt/proguard-android-optimize.txt/g' "$f"
      rm -f -- "${f}.bak"
      echo "patched: ${f}"
      n=$((n + 1))
    fi
  done < <(find "$cache/hosted" -type f \( -name 'build.gradle' -o -name 'build.gradle.kts' \) -path '*/android/*' -print0)
  echo "patch_pub_cache_agp9: ${n} berkas diperbaiki"
}
log "8/9 Patch plugin untuk AGP 9"
patch_pub_cache_agp9

# -----------------------------------------------------------------------------
# 9. Guard ERROR-05: R8 "Missing class ...mlkit.vision.text.korean..." dst.
#    Plugin text recognition mereferensikan recognizer Cina/Devanagari/Jepang/
#    Korea yang tidak dibundel (default hanya Latin). Rule ini meredam peringatan
#    itu. Jika aplikasi memakai skrip non-Latin, JANGAN pakai rule ini; tambahkan
#    dependensi bahasa di Gradle (lihat README plugin).
# -----------------------------------------------------------------------------
ensure_proguard_rules() {
  local f="android/app/proguard-rules.pro"
  local begin="# >>> NEXVORA R8 rules >>>"
  mkdir -p android/app
  if [[ -f "$f" ]] && grep -qF -- "$begin" "$f"; then
    echo "proguard-rules.pro: blok NEXVORA sudah ada"
  else
    {
      echo ""
      echo "$begin"
      cat <<'RULES'
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
RULES
      echo "# <<< NEXVORA R8 rules <<<"
    } >> "$f"
    echo "proguard-rules.pro: blok NEXVORA ditulis"
  fi
  if ! grep -rqs 'proguard-rules\.pro' android/app/build.gradle android/app/build.gradle.kts; then
    warn "android/app/build.gradle(.kts) tidak menyebut proguard-rules.pro; mengandalkan fallback bawaan Flutter."
  fi
}
log "9/9 Rule R8"
ensure_proguard_rules

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
BUILD_LOG="$(mktemp "${TMPDIR:-/tmp}/nexvora-build.XXXXXX")"
BUILD_ARGS=("$@")
if [[ "${NO_SHRINK:-0}" == "1" ]]; then BUILD_ARGS+=(--no-shrink); fi

run_build() {
  local rc=0
  set +e
  flutter build apk --release "$@" 2>&1 | tee "$BUILD_LOG"
  rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

log "Build APK release"
build_ok=0
if run_build ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}; then build_ok=1; fi

if [[ $build_ok -eq 0 && "${NO_SHRINK:-0}" != "1" ]] \
   && grep -qE 'minifyReleaseWithR8|Missing classes detected while running R8' "$BUILD_LOG"; then
  warn "R8 gagal. Rule yang disarankan R8 ada di bawah; tambahkan ke blok RULES di tools/build.sh."
  if [[ -f build/app/outputs/mapping/release/missing_rules.txt ]]; then
    echo "---- build/app/outputs/mapping/release/missing_rules.txt ----"
    cat build/app/outputs/mapping/release/missing_rules.txt
    echo "-------------------------------------------------------------"
  fi
  warn "Mengulang build dengan --no-shrink (APK TANPA shrink). Perbaiki rule R8 agar bisa kembali memakai shrink."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "APK dibangun TANPA shrink (fallback karena R8 gagal)." >> "$GITHUB_STEP_SUMMARY"
  fi
  if run_build ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} --no-shrink; then build_ok=1; fi
fi

[[ $build_ok -eq 1 ]] || die "Build APK gagal. Lihat log di atas."

if compgen -G 'build/app/outputs/flutter-apk/*.apk' > /dev/null; then
  ls -lh build/app/outputs/flutter-apk/*.apk
else
  die "Build selesai tetapi APK tidak ditemukan di build/app/outputs/flutter-apk/"
fi
