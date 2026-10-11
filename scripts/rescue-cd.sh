#!/bin/bash
# rescue-cd.sh — hardened sort/archive/inventory (Phase 1)
# Configurable classification, better parsing, logging, verification.
#
# Usage: scripts/rescue-cd.sh [options] [src-dir] [name]
#
# Options:
#   --go                 Live mode (default: dry-run)
#   -s, --src DIR        Source extracted folder
#   -n, --name NAME      Disc name for output
#   -o, --outdir DIR     Output base (default: ~/Desktop/CD-Archive)
#   --keep LIST          Comma-separated extra keep names
#   --junk LIST          Comma-separated extra junk names
#   -v, --verbose
#   -h, --help
#
# Classification defaults to safe review for unknowns.
# NOTHING deleted. You trash _junk/ after review.
# Supports patterns via env STARMAX_KEEP / STARMAX_JUNK or flags.

set -euo pipefail

SRC=""
NAME=""
OUTBASE="$HOME/Desktop/CD-Archive"
GO=0
VERBOSE=0
EXTRA_KEEP=""
EXTRA_JUNK=""

usage() { sed -n '2,20p' "$0" | sed 's/^# //'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --go) GO=1; shift ;;
    -s|--src) SRC="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -o|--outdir) OUTBASE="$2"; shift 2 ;;
    --keep) EXTRA_KEEP="$2"; shift 2 ;;
    --junk) EXTRA_JUNK="$2"; shift 2 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$SRC" ]]; then SRC="$1"
      elif [[ -z "$NAME" ]]; then NAME="$1"
      fi
      shift ;;
  esac
done

# Sensible defaults if missing
[[ -z "$SRC" ]] && SRC="$HOME/Desktop"
[[ -z "$NAME" ]] && NAME="rescued-$(date +%Y%m%d)"

DEST="$OUTBASE/$NAME"
KEEP="$DEST/keepers"
JUNK="$DEST/_junk"
REVIEW="$DEST/_review"
LOG="$DEST/rescue.log"

if [[ ! -d "$SRC" ]]; then echo "Source not found: $SRC"; exit 1; fi
mkdir -p "$DEST"
exec > >(tee -a "$LOG") 2>&1

echo "=== Starmax rescue: $NAME ==="
echo "Source: $SRC"
echo "Dest:   $DEST"
echo "Mode:   $([[ $GO -eq 1 ]] && echo LIVE || echo DRY-RUN)"

# Base classification (expandable)
junk_names=( "Desktop DB" "Desktop DF" "Preferences" "Previous System Folder" "Extensions" "System Folder" )
review_names=( "Applications" )
keep_names=( "Fonts" )

# Env + flags
IFS=',' read -ra ek <<< "${STARMAX_KEEP:-},${EXTRA_KEEP:-}"
IFS=',' read -ra ej <<< "${STARMAX_JUNK:-},${EXTRA_JUNK:-}"
for x in "${ek[@]}"; do [[ -n "$x" ]] && keep_names+=("$x"); done
for x in "${ej[@]}"; do [[ -n "$x" ]] && junk_names+=("$x"); done

in_list() { local w="$1"; shift; for x in "$@"; do [[ "$x" == "$w" ]] && return 0; done; return 1; }

do_move() {
  local item="$1" dest="$2"
  local srcpath="$SRC/$item"
  [[ -e "$srcpath" ]] || { echo "  skip (missing): $item"; return; }
  if [[ $GO -eq 1 ]]; then
    mkdir -p "$dest"
    if [[ -e "$dest/$item" ]]; then
      echo "  skip (exists): $item"
    else
      mv "$srcpath" "$dest/$item" && echo "  moved: $item -> $(basename "$dest")/"
    fi
  else
    echo "  would move: $item -> $(basename "$dest")/"
  fi
}

echo
echo "--- classification ---"
for i in "${keep_names[@]}"; do do_move "$i" "$KEEP"; done
for i in "${junk_names[@]}"; do do_move "$i" "$JUNK"; done
for i in "${review_names[@]}"; do do_move "$i" "$REVIEW"; done

# Remaining top-level -> review (safe)
while IFS= read -r -d '' entry; do
  base=$(basename "$entry")
  [[ "$base" == keepers || "$base" == _junk || "$base" == _review ]] && continue
  do_move "$base" "$REVIEW"
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

if [[ $GO -eq 0 ]]; then
  echo
echo "Dry-run complete. Re-run with --go to execute."
  exit 0
fi

echo
echo "--- inventory ---"
REPORT="$DEST/loot-report.txt"
{
  echo "Loot report — $NAME — $(date)"
  echo "Keepers: $KEEP"
  echo "ISO SHA (if present): $(cat "$HOME/cd-archive/$NAME.iso.sha256" 2>/dev/null || echo n/a)"
  echo
  echo "== Fonts =="
  find "$KEEP" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.pfb' -o -iname '*rsrc' \) 2>/dev/null | sed "s|$KEEP/||" || true
  echo
  echo "== QuarkXPress (.qxd) =="
  find "$KEEP" -type f -iname '*.qxd' 2>/dev/null | sed "s|$KEEP/||" || true
  echo
  echo "== Images (incl. PICT) =="
  find "$KEEP" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.pict' -o -iname '*.pct' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.bmp' -o -iname '*.png' \) 2>/dev/null | sed "s|$KEEP/||" || true
  echo
  echo "== Documents =="
  find "$KEEP" -type f \( -iname '*.txt' -o -iname '*.doc' -o -iname '*.rtf' -o -iname '*.pdf' -o -iname '*.html' \) 2>/dev/null | sed "s|$KEEP/||" || true
  echo
  echo "== Modernize checklist =="
  echo "[ ] Fonts: suitcases -> FontForge / TTF"
  echo "[ ] .qxd -> open in InDesign"
  echo "[ ] PICT -> PNG (sips or future pipeline)"
  echo "[ ] Review _review/ + trash _junk/"
} > "$REPORT"
echo "Report: $REPORT"

echo
echo "--- archive ---"
ZIP="$DEST/$NAME-keepers.zip"
if [[ ! -f "$ZIP" ]]; then
  (cd "$DEST" && zip -qr "$NAME-keepers.zip" keepers) && echo "Zip: $ZIP"
else
  echo "Zip exists, skipped."
fi

echo
echo "=== Done ==="
echo "Keepers: $KEEP"
echo "Log: $LOG"
echo "Next: review _review/ and _junk/, then trash _junk/."
