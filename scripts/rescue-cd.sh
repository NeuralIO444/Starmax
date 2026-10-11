#!/bin/bash
# rescue-cd.sh — CD rescue pipeline: one keepers folder, dump the junk,
# archive the loot, inventory everything worth modernizing.
#
# Usage:
#   ./rescue-cd.sh                        # dry run on the Starmax 4 disc
#   ./rescue-cd.sh --go                   # DO IT on the Starmax 4 disc
#   ./rescue-cd.sh <src-dir> <disc-name> [--go]
#
# Result in ~/Desktop/CD-Archive/<disc-name>/:
#   keepers/            — the good stuff, one folder
#   _junk/              — Finder caches, prefs, dead OS parts (trash this)
#   _review/            — unknowns for you to eyeball
#   <disc-name>-keepers.zip  — the archive
#   loot-report.txt     — fonts / Quark docs / images / emails inventory
#
# NOTHING IS DELETED BY THIS SCRIPT. You trash _junk/ yourself.

set -u

SRC="${1:-$HOME/Desktop/CD Name/Starmax 4.Back-up.10:18:98}"
NAME="${2:-Starmax-4-Backup-1998-10-18}"
GO=0
[[ "${3:-${1:-}}" == "--go" || "${2:-}" == "--go" || "${1:-}" == "--go" ]] && GO=1
# normalize: allow --go in any position
for a in "$@"; do [[ "$a" == "--go" ]] && GO=1; done
# if --go was passed as $1/$2, shift it out of the way
[[ "${1:-}" == "--go" ]] && { SRC="$HOME/Desktop/CD Name/Starmax 4.Back-up.10:18:98"; NAME="Starmax-4-Backup-1998-10-18"; }
[[ "${2:-}" == "--go" ]] && NAME="Starmax-4-Backup-1998-10-18"

DEST="$HOME/Desktop/CD-Archive/$NAME"
KEEP="$DEST/keepers"
JUNK="$DEST/_junk"
REVIEW="$DEST/_review"

if [[ ! -d "$SRC" ]]; then echo "Source not found: $SRC"; exit 1; fi

# --- classification -------------------------------------------------------
junk_names=( "Desktop DB" "Desktop DF" "Preferences"
             "Previous System Folder" "Extensions" )
review_names=( "Applications" "Expand Area" )
keep_names=( "Fonts" "MOZCO ICONS" "South Park Icons ƒ copy" "ZIP Shiznit.v10" )
# Anything else at top level -> _review (safe default)

in_list() { local want="$1"; shift; for x in "$@"; do [[ "$x" == "$want" ]] && return 0; done; return 1; }

do_move() { # $1=item $2=destdir
  local src="$SRC/$1" dest="$2"
  [[ -e "$src" ]] || { echo "  (skip) $1 — not present"; return; }
  if [[ $GO -eq 1 ]]; then
    mkdir -p "$dest"
    if [[ -e "$dest/$1" ]]; then echo "  (skip) $1 — already moved";
    else mv "$src" "$dest/$1" && echo "  moved: $1 -> $(basename "$dest")/"; fi
  else
    echo "  would move: $1 -> $(basename "$dest")/"
  fi
}

echo "=== CD rescue: $NAME ==="
echo "Source: $SRC"
echo "Dest:   $DEST"
[[ $GO -eq 1 ]] && echo "MODE: LIVE" || echo "MODE: DRY RUN (add --go to do it)"
echo
echo "--- keepers (one folder) ---"
for i in "${keep_names[@]}"; do do_move "$i" "$KEEP"; done
echo
echo "--- junk (trash after review) ---"
for i in "${junk_names[@]}"; do do_move "$i" "$JUNK"; done
echo
echo "--- review (eyeball these) ---"
for i in "${review_names[@]}"; do do_move "$i" "$REVIEW"; done
# anything left at top level -> review
while IFS= read -r -d '' entry; do
  base="$(basename "$entry")"
  [[ "$base" == "_junk" || "$base" == "_review" || "$base" == "keepers" ]] && continue
  do_move "$base" "$REVIEW"
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

if [[ $GO -eq 0 ]]; then
  echo; echo "Dry run done. Run with --go to execute."
  exit 0
fi

# --- loot inventory ---------------------------------------------------------
echo; echo "--- inventorying the loot ---"
REPORT="$DEST/loot-report.txt"
{
  echo "Loot report — $NAME — $(date)"
  echo "Keepers: $KEEP"
  echo
  echo "== Fonts =="
  find "$KEEP" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.pfb' -o -iname '.*.rsrc' \) 2>/dev/null | sed "s|$KEEP/||"
  echo
  echo "== QuarkXPress documents (open in InDesign: File > Open) =="
  find "$KEEP" -type f -iname '*.qxd' 2>/dev/null | sed "s|$KEEP/||"
  echo
  echo "== Images =="
  find "$KEEP" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.pict' -o -iname '*.pct' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.bmp' -o -iname '*.png' \) 2>/dev/null | sed "s|$KEEP/||"
  echo
  echo "== Documents =="
  find "$KEEP" -type f \( -iname '*.txt' -o -iname '*.doc' -o -iname '*.rtf' -o -iname '*.pdf' -o -iname '*.html' -o -iname '*.text' \) 2>/dev/null | sed "s|$KEEP/||"
  echo
  echo "== Possible emails / mailboxes =="
  find "$KEEP" -type f \( -iname '*mail*' -o -iname '*.mbox' -o -iname '*.eml' \) 2>/dev/null | sed "s|$KEEP/||"
  echo
  echo "== Modernize checklist =="
  echo "[ ] Fonts: suitcases/.bmap -> convert to TTF (ask Ember, or FontForge)"
  echo "[ ] .QXD files: open each in InDesign (File > Open), save as .indd"
  echo "[ ] .PICT images: convert to PNG (no native macOS support anymore)"
  echo "[ ] Review _review/ and _junk/ in Finder, then trash _junk/"
} > "$REPORT"
echo "Wrote: $REPORT"

# --- archive ----------------------------------------------------------------
echo; echo "--- archiving keepers ---"
ZIP="$DEST/$NAME-keepers.zip"
if [[ -f "$ZIP" ]]; then echo "(skip) archive already exists: $(basename "$ZIP")"
else ( cd "$DEST" && zip -qr "$NAME-keepers.zip" keepers ) && echo "Wrote: $ZIP"; fi

echo
echo "=== Done ==="
echo "Keepers:  $KEEP"
echo "Archive:  $ZIP"
echo "Report:   $REPORT"
echo "Next: review _review/ and _junk/ in Finder, then trash _junk/ yourself."
