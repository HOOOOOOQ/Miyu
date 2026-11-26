#!/usr/bin/env bash
# Prints the SHA-1 / SHA-256 fingerprints to register in Google Cloud Console
# for the Android OAuth client of com.miyu.messaging.
#
#   bash tool/print_sha1.sh              # debug keystore + release key.properties (if any)
#   bash tool/print_sha1.sh path/to.jks  # a specific keystore (prompts for passwords)
#
# You need a JDK on PATH (keytool ships with it). If keytool is missing but the
# Android SDK is installed, `./gradlew signingReport` prints the same values.
set -euo pipefail

ANDROID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/android"

print_keystore() {
  local store="$1" alias="${2:-}" storepass="${3:-}" keypass="${4:-}"
  [[ -f "$store" ]] || { echo "  (not found: $store)"; return; }
  echo "  keystore: $store"
  local args=(-list -v -keystore "$store")
  [[ -n "$alias" ]] && args+=(-alias "$alias")
  [[ -n "$storepass" ]] && args+=(-storepass "$storepass")
  [[ -n "$keypass" ]] && args+=(-keypass "$keypass")
  keytool "${args[@]}" 2>/dev/null | grep -E "^(Alias name|Owner|Valid from)|SHA1:|SHA256:" | sed 's/^/  /'
  echo
}

echo "== package / applicationId =="
grep -E 'applicationId|namespace' "$ANDROID_DIR/app/build.gradle" | sed 's/^/  /'
echo

if [[ $# -ge 1 ]]; then
  echo "== custom keystore =="
  print_keystore "$1"
  exit 0
fi

echo "== debug keystore (used by 'flutter run' / debug builds) =="
print_keystore "$HOME/.android/debug.keystore" androiddebugkey android android

echo "== release keystore (from android/key.properties) =="
if [[ -f "$ANDROID_DIR/key.properties" ]]; then
  # shellcheck disable=SC1091
  store=$(grep -E '^storeFile=' "$ANDROID_DIR/key.properties" | cut -d= -f2-)
  alias=$(grep -E '^keyAlias=' "$ANDROID_DIR/key.properties" | cut -d= -f2-)
  storepass=$(grep -E '^storePassword=' "$ANDROID_DIR/key.properties" | cut -d= -f2-)
  keypass=$(grep -E '^keyPassword=' "$ANDROID_DIR/key.properties" | cut -d= -f2-)
  # storeFile is relative to android/app in build.gradle.
  [[ "$store" = /* ]] || store="$ANDROID_DIR/app/$store"
  print_keystore "$store" "${alias:-}" "${storepass:-}" "${keypass:-}"
else
  echo "  (no key.properties — release builds are debug-signed unless you add one)"
fi

cat <<'NOTE'
Register every fingerprint above (debug AND release, plus the Play App Signing
SHA-1 shown in Play Console → App integrity) on the SAME Android OAuth client:
  Google Cloud Console → APIs & Services → Credentials → your Android client ID
Mismatch is the #1 cause of ApiException: 10 / DEVELOPER_ERROR.
NOTE
