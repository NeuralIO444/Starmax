#!/bin/bash
# rescue-cd.sh — Phase 2 + clone-by-default
# Clone is ON by default (full unmodified copy first). Sorting is a second pass.
# Heuristics on by default (evaluated in dry-run too). Broader: QXD, fonts, images.
#
# Usage: scripts/rescue-cd.sh [options] [src-dir] [name]
#
# Options:
#   --go                 Live mode (default dry-run)
#   --clone              Explicit clone (default ON)
#   --no-clone           Disable the full unmodified copy
#   -s, --src DIR        Source extracted folder
#   -n, --name NAME      Disc name
#   -o, --outdir DIR     Output base (default: ~/Desktop/CD-Archive)
#   --keep LIST          Extra keep names (comma)
#   --junk LIST          Extra junk names (comma)
#   --convert-pict       Side-by-side PICT/PCT → PNG via sips
#   --extract-sit        Extract .sit/.sitx with unar (if present)
#   --convert-fonts      Stub: print FontForge commands if present
#   --sanitize           Basic rename of problematic old-Mac names before processing
#   --manifest           Write keepers.manifest.json (default on with --go)
#   --no-heuristics      Disable recursive content heuristics
#   -v, --verbose
#   -h, --help
#
# NOTHING is deleted. Junk goes to _junk/; you trash it in Finder after review.
# With clone (default) the original extract layout is preserved under full-extract/.
# Keep patterns: STARMAX_KEEP_PATTERNS env (comma globs) or ~/.starmax-keep (one glob per line).

set -euo pipefail

SRC=""
NAME=""
OUTBASE="$HOME/Desktop/CD-Archive"
GO=0
CLONE=1
VERBOSE=0
CONVERT_PICT=0
EXTRACT_SIT=0
CONVERT_FONTS=0
SANITIZE=0
DO_MANIFEST=1
HEURISTICS=1
EXTRA_KEEP=""
EXTRA_JUNK=""

usage() { sed -n '2,32p' "$0" | sed 's/^# //'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --go) GO=1; shift ;;
    --clone) CLONE=1; shift ;;
    --no-clone) CLONE=0; shift ;;
    -s|--src) SRC="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -o|--outdir) OUTBASE="$2"; shift 2 ;;
    --keep) EXTRA_KEEP="$2"; shift 2 ;;
    --junk) EXTRA_JUNK="$2"; shift 2 ;;
    --convert-pict) CONVERT_PICT=1; shift ;;
    --extract-sit) EXTRACT_SIT=1; shift ;;
    --convert-fonts) CONVERT_FONTS=1; shift ;;
    --sanitize) SANITIZE=1; shift ;;
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
CLONE_DEST="$DEST/full-extract"
LOG="$DEST/rescue.log"

if [[ ! -d "$SRC" ]]; then echo "Source not found: $SRC"; exit 1; fi
mkdir -p "$DEST"
exec > >(tee -a "$LOG") 2>&1

echo "=== Starmax rescue: $NAME ==="
echo "Source: $SRC"
echo "Dest:   $DEST"
echo "Mode:   $([[ $GO -eq 1 ]] && echo LIVE || echo DRY-RUN)"
echo "Clone:   $([[ $CLONE -eq 1 ]] && echo ON (default) || echo OFF)"
echo "Heuristics: $([[ $HEURISTICS -eq 1 ]] && echo ON || echo OFF)"
echo "Sanitize: $([[ $SANITIZE -eq 1 ]] && echo ON || echo OFF)"

# --- Optional sanitize (rename problematic names in source before clone/sort) ---
if [[ $SANITIZE -eq 1 && $GO -eq 1 ]]; then
  echo
  echo "--- sanitize ---"
  find "$SRC" -depth -print0 2>/dev/null | while IFS= read -r -d '' p; do
    base=$(basename "$p")
    dir=$(dirname "$p")
    safe=$(printf '%s' "$base" | sed 's/[:\n\r]/_/g; s/^[[:space:]]*//; s/[[:space:]]*$//; s/Icon\n/Icon_/g' | cut -c1-200)
    [[ "$base" == "$safe" ]] && continue
    [[ -z "$safe" ]] && safe="unnamed-$(date +%s)"
    mv -n "$p" "$dir/$safe" 2>/dev/null && echo "  sanitized: $base → $safe" || true
  done || true
fi

# --- Clone mode (full unmodified copy) — default ON ---
if [[ $CLONE -eq 1 ]]; then
  echo
  echo "--- clone (full unmodified copy) ---"
  if [[ $GO -eq 1 ]]; then
    if [[ -d "$CLONE_DEST" ]]; then
      echo "  full-extract already exists, skipped."
    else
      mkdir -p "$CLONE_DEST"
      cp -a "$SRC"/. "$CLONE_DEST"/ && echo "  cloned to $CLONE_DEST"
    fi
  else
    echo "  would clone entire source to $CLONE_DEST"
  fi
fi

# Classification lists
junk_names=( "Desktop DB" "Desktop DF" "Preferences" "Previous System Folder" "Extensions" "System Folder" )
review_names=( "Applications" )
keep_names=( "Fonts" )

IFS=',' read -ra ek <<< "${STARMAX_KEEP:-},${EXTRA_KEEP:-}"
IFS=',' read -ra ej <<< "${STARMAX_JUNK:-},${EXTRA_JUNK:-}"
for x in "${ek[@]}"; do [[ -n "$x" ]] && keep_names+=("$x"); done
for x in "${ej[@]}"; do [[ -n "$x" ]] && junk_names+=("$x"); done

# Load keep patterns
KEEP_PATTERNS=()
if [[ -f "$HOME/.starmax-keep" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" && ! "$line" =~ ^# ]] && KEEP_PATTERNS+=("$line")
  done < "$HOME/.starmax-keep"
fi
IFS=',' read -ra env_pats <<< "${STARMAX_KEEP_PATTERNS:-}"
for p in "${env_pats[@]}"; do [[ -n "$p" ]] && KEEP_PATTERNS+=("$p"); done

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

# Remaining top-level (heuristics evaluated even in dry-run)
while IFS= read -r -d '' entry; do
  base=$(basename "$entry")
  [[ "$base" == keepers || "$base" == _junk || "$base" == _review || "$base" == full-extract ]] && continue

  # Pattern match
  for pat in "${KEEP_PATTERNS[@]}"; do
    # shellcheck disable=SC2254
    case "$base" in
      $pat) do_move "$base" "$KEEP"; echo "  pattern → keepers: $base"; continue 2 ;;
    esac
  done

  if [[ $HEURISTICS -eq 1 ]]; then
    qxd=$(find "$SRC/$base" -type f -iname '*.qxd' 2>/dev/null | wc -l | tr -d ' ')
    fonts=$(find "$SRC/$base" -type f \( -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.ttf' \) 2>/dev/null | wc -l | tr -d ' ')
    images=$(find "$SRC/$base" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pict' -o -iname '*.pct' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.gif' \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$qxd" -ge 1 || "$fonts" -ge 2 || "$images" -ge 5 ]]; then
      do_move "$base" "$KEEP"
      echo "  heuristic → keepers: $base (qxd=$qxd fonts=$fonts images=$images)"
      continue
    fi
  fi
  do_move "$base" "$REVIEW"
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

if [[ $GO -eq 0 ]]; then
  echo
  echo "Dry-run complete. Re-run with --go."
  exit 0
fi

# Ensure keepers dir exists so later steps don't abort
mkdir -p "$KEEP"

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
  done || true
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
    done || true
  fi
fi

# --- Font conversion stub ---
if [[ $CONVERT_FONTS -eq 1 ]]; then
  echo
  echo "--- font conversion stub ---"
  if command -v fontforge >/dev/null 2>&1; then
    echo "  fontforge is installed. Example for a suitcase:"
    echo "    fontforge -c 'Open(\"$KEEP/some.suit\"); Generate(\"$KEEP/some.ttf\")'"
  else
    echo "  fontforge not found (brew install fontforge). Detection only."
  fi
fi

# --- Inventory (MD + JSON) ---
echo
echo "--- inventory ---"
MD="$DEST/loot-report.md"
JSON="$DEST/loot-report.json"

python3 - "$KEEP" "$JSON" "$NAME" <<'PY' || true
import os, sys, json, time
from pathlib import Path
keep, out, name = sys.argv[1], sys.argv[2], sys.argv[3]
files = []
if os.path.isdir(keep):
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
  echo "- [ ] Fonts: suitcases/.bmap → FontForge / TTF (use --convert-fonts for stub commands)"
  echo "- [ ] .qxd → open in InDesign (File → Open). Install recovered TTFs first."
  echo "- [ ] PICT originals kept; PNGs side-by-side if --convert-pict was used"
  echo "- [ ] Review _review/ and trash _junk/ in Finder"
  echo "- [ ] ISO remains the preservation master"
  [[ $CLONE -eq 1 ]] && echo "- [ ] Full unmodified extract is in full-extract/"
} > "$MD"
echo "Markdown report: $MD"
echo "JSON inventory: $JSON"

# --- Manifest ---
if [[ $DO_MANIFEST -eq 1 ]]; then
  echo
  echo "--- keepers manifest ---"
  MANIFEST="$DEST/keepers.manifest.json"
  python3 - "$KEEP" "$MANIFEST" <<'PY' || true
import os, sys, json, hashlib, time
from pathlib import Path
keep, out = sys.argv[1], sys.argv[2]
entries = []
if os.path.isdir(keep):
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

# --- Simple verification ---
echo
echo "--- verification ---"
SRC_COUNT=$(find "$SRC" -type f 2>/dev/null | wc -l | tr -d ' ')
KEEP_COUNT=$(find "$KEEP" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "  Source files: $SRC_COUNT"
echo "  Keepers files: $KEEP_COUNT"
[[ $CLONE -eq 1 && -d "$CLONE_DEST" ]] && echo "  Full-extract files: $(find "$CLONE_DEST" -type f 2>/dev/null | wc -l | tr -d ' ')"

# --- Archive ---
echo
echo "--- archive ---"
ZIP="$DEST/$NAME-keepers.zip"
if [[ ! -f "$ZIP" ]]; then
  (cd "$DEST" && zip -qr "$NAME-keepers.zip" keepers) && echo "Zip: $ZIP" || echo "Zip skipped (empty or error)"
else
  echo "Zip exists, skipped."
fi

echo
echo "=== Done ==="
echo "Keepers: $KEEP"
[[ $CLONE -eq 1 ]] && echo "Full extract: $CLONE_DEST"
echo "Reports: $MD / $JSON"
echo "Log: $LOG"
echo "Next: review _review/ and _junk/, then trash _junk/ yourself. ISO stays the master."
