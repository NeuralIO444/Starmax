#!/bin/bash
# rescue-cd.sh — Phase 2: sort + convert + inventory + manifest
# Heuristics on by default. PICT side-by-side. .sit extract. MD+JSON reports.
#
# Usage: scripts/rescue-cd.sh [options] [src-dir] [name]
#
# Options:
#   --go                 Live mode (default dry-run)
#   -s, --src DIR        Source extracted folder
#   -n, --name NAME      Disc name
#   -o, --outdir DIR     Output base (default: ~/Desktop/CD-Archive)
#   --keep LIST          Extra keep names (comma)
#   --junk LIST          Extra junk names (comma)
#   --convert-pict       Side-by-side PICT/PCT → PNG via sips
#   --extract-sit        Extract .sit/.sitx with unar (if present)
#   --manifest           Write keepers.manifest.json (default on with --go)
#   --no-heuristics      Disable recursive content heuristics
#   -v, --verbose
#   -h, --help
#
# NOTHING is deleted. Junk goes to _junk/; you trash it in Finder after review.

set -euo pipefail

SRC=""
NAME=""
OUTBASE="$HOME/Desktop/CD-Archive"
GO=0
VERBOSE=0
CONVERT_PICT=0
EXTRACT_SIT=0
DO_MANIFEST=1
HEURISTICS=1
EXTRA_KEEP=""
EXTRA_JUNK=""

usage() { sed -n '2,22p' "$0" | sed 's/^# //'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --go) GO=1; shift ;;
    -s|--src) SRC="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -o|--outdir) OUTBASE="$2"; shift 2 ;;
    --keep) EXTRA_KEEP="$2"; shift 2 ;;
    --junk) EXTRA_JUNK="$2"; shift 2 ;;
    --convert-pict) CONVERT_PICT=1; shift ;;
    --extract-sit) EXTRACT_SIT=1; shift ;;
    --manifest) DO_MANIFEST=1; shift ;;
    --no-heuristics) HEURISTICS=0; shift ;;
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

echo "=== Starmax rescue Phase 2: $NAME ==="
echo "Source: $SRC"
echo "Dest:   $DEST"
echo "Mode:   $([[ $GO -eq 1 ]] && echo LIVE || echo DRY-RUN)"
echo "Heuristics: $([[ $HEURISTICS -eq 1 ]] && echo ON || echo OFF)"

# Classification lists
junk_names=( "Desktop DB" "Desktop DF" "Preferences" "Previous System Folder" "Extensions" "System Folder" )
review_names=( "Applications" )
keep_names=( "Fonts" )

IFS=',' read -ra ek <<< "${STARMAX_KEEP:-},${EXTRA_KEEP:-}"
IFS=',' read -ra ej <<< "${STARMAX_JUNK:-},${EXTRA_JUNK:-}"
for x in "${ek[@]}"; do [[ -n "$x" ]] && keep_names+=("$x"); done
for x in "${ej[@]}"; do [[ -n "$x" ]] && junk_names+=("$x"); done

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
echo "--- explicit classification ---"
for i in "${keep_names[@]}"; do do_move "$i" "$KEEP"; done
for i in "${junk_names[@]}"; do do_move "$i" "$JUNK"; done
for i in "${review_names[@]}"; do do_move "$i" "$REVIEW"; done

# Remaining top-level
while IFS= read -r -d '' entry; do
  base=$(basename "$entry")
  [[ "$base" == keepers || "$base" == _junk || "$base" == _review ]] && continue
  if [[ $HEURISTICS -eq 1 && $GO -eq 1 ]]; then
    # Simple content heuristic
    qxd=$(find "$SRC/$base" -type f -iname '*.qxd' 2>/dev/null | wc -l | tr -d ' ')
    fonts=$(find "$SRC/$base" -type f \( -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.ttf' \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$qxd" -ge 1 || "$fonts" -ge 2 ]]; then
      do_move "$base" "$KEEP"
      echo "  heuristic → keepers: $base (qxd=$qxd fonts=$fonts)"
      continue
    fi
  fi
  do_move "$base" "$REVIEW"
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

if [[ $GO -eq 0 ]]; then
  echo
  echo "Dry-run complete. Re-run with --go (and optional --convert-pict --extract-sit)."
  exit 0
fi

# --- Phase 2: PICT side-by-side ---
if [[ $CONVERT_PICT -eq 1 ]]; then
  echo
  echo "--- PICT → PNG (side-by-side) ---"
  find "$KEEP" -type f \( -iname '*.pict' -o -iname '*.pct' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
    png="${f%.*}.png"
    if [[ -e "$png" ]]; then
      echo "  skip (exists): $png"
    else
      sips -s format png "$f" --out "$png" >/dev/null 2>&1 && echo "  converted: $(basename "$f") → $(basename "$png")" || echo "  failed: $f"
    fi
  done
fi

# --- Phase 2: StuffIt ---
if [[ $EXTRACT_SIT -eq 1 ]]; then
  echo
  echo "--- StuffIt extract ---"
  if ! command -v unar >/dev/null 2>&1; then
    echo "  unar not found (brew install unar). Skipping."
  else
    find "$KEEP" -type f \( -iname '*.sit' -o -iname '*.sitx' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
      base=$(basename "$f")
      outdir="$KEEP/unarchived/${base%.*}"
      if [[ -d "$outdir" ]]; then
        echo "  skip (exists): $outdir"
      else
        mkdir -p "$outdir"
        unar -quiet -output-directory "$outdir" "$f" && echo "  extracted: $base → unarchived/" || echo "  failed: $f"
      fi
    done
  fi
fi

# --- Inventory (MD + JSON) ---
echo
echo "--- inventory ---"
MD="$DEST/loot-report.md"
JSON="$DEST/loot-report.json"

# Simple JSON inventory via python for reliability
python3 - "$KEEP" "$JSON" "$NAME" <<'PY'
import os, sys, json, hashlib, time
from pathlib import Path
keep, out, name = sys.argv[1], sys.argv[2], sys.argv[3]
files = []
for root, dirs, fs in os.walk(keep):
    for fn in fs:
        p = Path(root)/fn
        try:
            st = p.stat()
            rel = str(p.relative_to(keep))
            ext = p.suffix.lower()
            files.append({
                "path": rel,
                "size": st.st_size,
                "mtime": int(st.st_mtime),
                "ext": ext,
                "is_font": ext in {".ttf",".otf",".suit",".dfont",".bmap",".pfb"} or "rsrc" in fn.lower(),
                "is_qxd": ext == ".qxd",
                "is_pict": ext in {".pict",".pct"},
                "is_sit": ext in {".sit",".sitx"}
            })
        except Exception:
            pass
manifest = {"name": name, "generated": int(time.time()), "files": files}
with open(out, "w") as f:
    json.dump(manifest, f, indent=2)
print(f"JSON inventory: {len(files)} files")
PY

{
  echo "# Loot report — $NAME"
  echo ""
  echo "Generated: $(date)"
  echo ""
  echo "## Fonts (better detection)"
  find "$KEEP" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.pfb' -o -iname '*rsrc' \) 2>/dev/null | sed "s|$KEEP/||" || true
  echo ""
  echo "## QuarkXPress (.qxd)"
  find "$KEEP" -type f -iname '*.qxd' 2>/dev/null | sed "s|$KEEP/||" || true
  echo ""
  echo "## Images (original + any side-by-side PNG)"
  find "$KEEP" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.pict' -o -iname '*.pct' -o -iname '*.png' -o -iname '*.tiff' -o -iname '*.tif' \) 2>/dev/null | sed "s|$KEEP/||" || true
  echo ""
  echo "## StuffIt archives"
  find "$KEEP" -type f \( -iname '*.sit' -o -iname '*.sitx' \) 2>/dev/null | sed "s|$KEEP/||" || true
  echo ""
  echo "## Modernize checklist"
  echo "- [ ] Fonts: suitcases/.bmap → FontForge / TTF (detection only in this phase)"
  echo "- [ ] .qxd → open in InDesign (File → Open). Install recovered TTFs first."
  echo "- [ ] PICT originals kept; PNGs side-by-side if --convert-pict was used"
  echo "- [ ] Review _review/ and trash _junk/ in Finder"
  echo "- [ ] ISO remains the preservation master"
} > "$MD"
echo "Markdown report: $MD"
echo "JSON inventory: $JSON"

# --- Manifest ---
if [[ $DO_MANIFEST -eq 1 ]]; then
  echo
  echo "--- keepers manifest ---"
  MANIFEST="$DEST/keepers.manifest.json"
  python3 - "$KEEP" "$MANIFEST" <<'PY'
import os, sys, json, hashlib, time
from pathlib import Path
keep, out = sys.argv[1], sys.argv[2]
entries = []
for root, dirs, fs in os.walk(keep):
    for fn in fs:
        p = Path(root)/fn
        try:
            data = p.read_bytes()
            h = hashlib.sha256(data).hexdigest()
            st = p.stat()
            entries.append({
                "path": str(p.relative_to(keep)),
                "size": st.st_size,
                "mtime": int(st.st_mtime),
                "sha256": h
            })
        except Exception:
            pass
with open(out, "w") as f:
    json.dump({"generated": int(time.time()), "files": entries}, f, indent=2)
print(f"Manifest: {len(entries)} files → {out}")
PY
fi

# --- Archive ---
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
echo "Reports: $MD / $JSON"
echo "Log: $LOG"
echo "Next: review _review/ and _junk/, then trash _junk/ yourself. ISO stays the master."
