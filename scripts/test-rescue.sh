#!/bin/bash
# test-rescue.sh — simple fixture test for rescue-cd.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/fixture/Fonts" "$TMP/fixture/Project"
echo "font" > "$TMP/fixture/Fonts/test.suit"
for i in {1..6}; do echo "img" > "$TMP/fixture/Project/img$i.jpg"; done
echo "qxd" > "$TMP/fixture/Project/test.qxd"

echo "=== dry-run test ==="
"$SCRIPT_DIR/rescue-cd.sh" --src "$TMP/fixture" --name test-dry --plan || true

echo "=== live test (no-clone) ==="
"$SCRIPT_DIR/rescue-cd.sh" --src "$TMP/fixture" --name test-live --go --no-clone --sanitize || true

echo "Test complete. Check $HOME/Desktop/CD-Archive/test-* if needed."
