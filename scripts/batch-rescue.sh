#!/bin/bash
# batch-rescue.sh — Phase 3: run rescue-cd.sh across a folder of extracts
#
# Usage: scripts/batch-rescue.sh [options] <dir-of-extracts>
#
# Options:
#   --only PATTERN     Only process folders whose name matches the glob (e.g. 'Starmax*')
#   --clone --convert-pict --extract-sit --no-heuristics etc. (passed through)
#
# Example:
#   scripts/batch-rescue.sh --only 'Starmax*' --clone --convert-pict ~/Desktop/
#
# Skips the output directory (CD-Archive) automatically so it never clones itself.
# Each matching subdirectory is treated as one disc extract.
# Output goes to ~/Desktop/CD-Archive/<name>/
# Summary: ~/Desktop/CD-Archive/batch-summary.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESCUE="$SCRIPT_DIR/rescue-cd.sh"
OUTBASE="$HOME/Desktop/CD-Archive"
SUMMARY="$OUTBASE/batch-summary.txt"
EXTRA_ARGS=()
ONLY_PATTERN=""
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      ONLY_PATTERN="$2"
      shift 2 ;;
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

[[ -z "$TARGET" ]] && { echo "Usage: $0 [--only 'Starmax*'] [--clone ...] <dir-of-extracts>"; exit 1; }
[[ -d "$TARGET" ]] || { echo "Not a directory: $TARGET"; exit 1; }

mkdir -p "$OUTBASE"
echo "=== Starmax batch rescue $(date) ===" | tee "$SUMMARY"
echo "Source dir: $TARGET" | tee -a "$SUMMARY"
echo "Only pattern: ${ONLY_PATTERN:-none}" | tee -a "$SUMMARY"
echo "Flags: ${EXTRA_ARGS[*]:-none}" | tee -a "$SUMMARY"
echo | tee -a "$SUMMARY"

count=0
while IFS= read -r -d '' dir; do
  name=$(basename "$dir")

  # Always skip the output directory itself
  if [[ "$name" == "CD-Archive" || "$dir" == "$OUTBASE" ]]; then
    echo "SKIP (output dir): $name" | tee -a "$SUMMARY"
    continue
  fi

  # Optional name filter
  if [[ -n "$ONLY_PATTERN" ]]; then
    # shellcheck disable=SC2254
    case "$name" in
      $ONLY_PATTERN) ;;
      *) echo "SKIP (pattern): $name" | tee -a "$SUMMARY"; continue ;;
    esac
  fi

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
