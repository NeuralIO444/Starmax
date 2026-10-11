#!/bin/bash
# batch-rescue.sh — Phase 3: run rescue-cd.sh across a folder of extracts
#
# Usage: scripts/batch-rescue.sh [options] <dir-of-extracts>
#
# Options passed through to each rescue-cd.sh invocation:
#   --clone --convert-pict --extract-sit --no-heuristics etc.
#
# Example:
#   scripts/batch-rescue.sh --clone --convert-pict ~/Desktop/Extracts/
#
# Each subdirectory is treated as one disc extract.
# Name is derived from the folder name.
# Output goes to ~/Desktop/CD-Archive/<name>/
# A summary is written to ~/Desktop/CD-Archive/batch-summary.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESCUE="$SCRIPT_DIR/rescue-cd.sh"
OUTBASE="$HOME/Desktop/CD-Archive"
SUMMARY="$OUTBASE/batch-summary.txt"
EXTRA_ARGS=()
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone|--convert-pict|--extract-sit|--no-heuristics|--go)
      EXTRA_ARGS+=("$1")
      shift ;;
    -*)
      EXTRA_ARGS+=("$1")
      shift ;;
    *)
      TARGET="$1"
      shift ;;
  esac
done

[[ -z "$TARGET" ]] && { echo "Usage: $0 [--clone ...] <dir-of-extracts>"; exit 1; }
[[ -d "$TARGET" ]] || { echo "Not a directory: $TARGET"; exit 1; }

mkdir -p "$OUTBASE"
echo "=== Starmax batch rescue $(date) ===" | tee "$SUMMARY"
echo "Source dir: $TARGET" | tee -a "$SUMMARY"
echo "Flags: ${EXTRA_ARGS[*]:-none}" | tee -a "$SUMMARY"
echo | tee -a "$SUMMARY"

count=0
while IFS= read -r -d '' dir; do
  name=$(basename "$dir")
  echo "--- Processing: $name ---" | tee -a "$SUMMARY"
  if "$RESCUE" --src "$dir" --name "$name" --go "${EXTRA_ARGS[@]}" >>"$SUMMARY" 2>&1; then
    echo "OK: $name" | tee -a "$SUMMARY"
  else
    echo "FAILED: $name" | tee -a "$SUMMARY"
  fi
  echo | tee -a "$SUMMARY"
  ((count++))
done < <(find "$TARGET" -mindepth 1 -maxdepth 1 -type d -print0)

echo "=== Batch complete: $count items ===" | tee -a "$SUMMARY"
echo "Summary: $SUMMARY"
