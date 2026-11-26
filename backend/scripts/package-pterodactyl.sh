#!/usr/bin/env bash
# Build the zip you upload to the Pterodactyl File Manager.
#
#   bash backend/scripts/package-pterodactyl.sh
#
# Output: dist/miyu-backend-pterodactyl.zip
# Contains the backend only (no tests, no node_modules, no .env) so the archive
# stays small enough for the panel upload limit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT/dist"
OUT="$OUT_DIR/miyu-backend-pterodactyl.zip"

mkdir -p "$OUT_DIR"
rm -f "$OUT"

cd "$ROOT/backend"
zip -rq "$OUT" . \
  -x "node_modules/*" \
  -x "tests/*" \
  -x "coverage/*" \
  -x ".jest/*" \
  -x ".env" \
  -x ".env.*" \
  -x "npm-debug.log*" \
  -x "jest.config.js" \
  -x "eslint.config.js" \
  -x "scripts/*"

echo "Built: $OUT"
echo "Size:  $(du -h "$OUT" | cut -f1)"
echo
echo "Files:"
unzip -l "$OUT" | tail -n +4 | head -n -2 | awk '{print "  " $4}'
