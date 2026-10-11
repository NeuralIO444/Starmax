#!/bin/bash
# batch-rescue.sh — run rescue-cd.sh across a folder of extracts
# Clone is default inside rescue-cd.sh. Supports dry-run and already-processed skip.
#
# Usage: scripts/batch-rescue.sh [options] <dir-of-extracts>
#
# Options:
#   --only PATTERN     Only process folders whose name matches the glob (e.g. 'Starmax*')
#   --dry-run          Pass through as dry-run (do not force --go)
#   --skip-processed   Skip if dest already has full-extract/ or keepers/
#   Other flags passed through to rescue-cd.sh
#
# Example:
#   scripts/batch-rescue.sh --only 'Starmax*' --skip-processed ~/Desktop/
#
# Skips the output directory (CD-Archive) automatically.
# Summary is timestamped under ~/Desktop/CD-Archive/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESCUE="$SCRIPT_DIR/rescue-cd.sh"
OUTBASE="$HOME/Desktop/CD-Archive"
TS=$(date +%Y%m%d-%H%M%S)
SUMMARY="$OUTBASE/batch-summary-$TS.txt"
EXTRA_ARGS=()
ONLY_PATTERN=""
TARGET=""
DRY=0
SKIP_PROCESSED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      ONLY_PATTERN="$2"
      shift 2 ;;
    --dry-run)
      DRY=1
      shift ;;
    --skip-processed)
      SKIP_PROCESSED=1
      shift ;;
    --clone|--no-clone|--convert-pict|--extract-sit|--convert-fonts|--sanitize|--no-heuristics|--go)
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

[[ -z "$TARGET" ]] && { echo "Usage: $0 [--only 'Starmax*'] [--dry-run] [--skip-processed] [--no-clone ...] <dir-of-extracts>"; exit 1; }
[[ -d "$TARGET" ]] || { echo "Not a directory: $TARGET"; exit 1; }

mkdir -p "$OUTBASE"
echo "=== Starmax batch rescue $TS ===" | tee "$SUMMARY"
echo "Source dir: $TARGET" | tee -a "$SUMMARY"
echo "Only pattern: ${ONLY_PATTERN:-none}" | tee -a "$SUMMARY"
echo "Dry-run: $DRY" | tee -a "$SUMMARY"
echo "Skip processed: $SKIP_PROCESSED" | tee -a "$SUMMARY"
echo "Flags: ${EXTRA_ARGS[*]:-none}" | tee -a "$SUMMARY"
echo | tee -a "$SUMMARY"

count=0
while IFS= read -r -d '' dir; do
  name=$(basename "$dir")

  if [[ "$name" == "CD-Archive" || "$dir" == "$OUTBASE" ]]; then
    echo "SKIP (output dir): $name" | tee -a "$SUMMARY"
    continue
  fi

  if [[ -n "$ONLY_PATTERN" ]]; then
    # shellcheck disable=SC2254
    case "$name" in
      $ONLY_PATTERN) ;;
      *) echo "SKIP (pattern): $name" | tee -a "$SUMMARY"; continue ;;
    esac
  fi

  dest="$OUTBASE/$name"
  if [[ $SKIP_PROCESSED -eq 1 && ( -d "$dest/full-extract" || -d "$dest/keepers" ) ]]; then
    echo "SKIP (already processed): $name" | tee -a "$SUMMARY"
    continue
  fi

  echo "--- Processing: $name ---" | tee -a "$SUMMARY"
  args=( --src "$dir" --name "$name" "${EXTRA_ARGS[@]}" )
  [[ $DRY -eq 0 ]] && args+=( --go )
  if "$RESCUE" "${args[@]}" >>"$SUMMARY" 2>&1; then
    echo "OK: $name" | tee -a "$SUMMARY"
  else
    echo "FAILED: $name" | tee -a "$SUMMARY"
  fi
  echo | tee -a "$SUMMARY"
  ((count++))
done < <(find "$TARGET" -mindepth 1 -maxdepth 1 -type d -print0)

echo "=== Batch complete: $count items ===" | tee -a "$SUMMARY"
echo "Summary: $SUMMARY"
