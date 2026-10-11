#!/bin/bash
# rescue-cd.sh — engineering pass
# Clone ON by default. macOS bash 3.2 compatible.
#
# Usage: scripts/rescue-cd.sh [options] [src] [name]
#
# Options:
#   --go --plan --no-clone --sanitize --export-modern --notify
#   --verify          SHA-256 every keepers file into verification.json
#   --convert-fonts   copy font files into modern/fonts (stub)
#   --no-heuristics
# Config: ~/.starmax.toml or ~/.starmax.conf

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/starmax-config.sh"

SRC=""
NAME=""
OUTBASE="$HOME/Desktop/CD-Archive"
GO=0
PLAN=0
CLONE=1
SANITIZE=0
EXPORT_MODERN=0
CONVERT_PICT=0
EXTRACT_SIT=0
CONVERT_FONTS=0
HEURISTICS=1
VERIFY=0
NOTIFY=${STARMAX_NOTIFY:-0}
EXTRA_KEEP=""
EXTRA_JUNK=""

usage() { sed -n '2,18p' "$0" | sed 's/^# //'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --go) GO=1; shift ;;
    --plan) PLAN=1; shift ;;
    --no-clone) CLONE=0; shift ;;
    --sanitize) SANITIZE=1; shift ;;
    --export-modern) EXPORT_MODERN=1; shift ;;
    --convert-pict) CONVERT_PICT=1; shift ;;
    --extract-sit) EXTRACT_SIT=1; shift ;;
    --convert-fonts) CONVERT_FONTS=1; shift ;;
    --no-heuristics) HEURISTICS=0; shift ;;
    --verify) VERIFY=1; shift ;;
    --notify) NOTIFY=1; shift ;;
    -s|--src) SRC="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -o|--outdir) OUTBASE="$2"; shift 2 ;;
    --keep) EXTRA_KEEP="$2"; shift 2 ;;
    --junk) EXTRA_JUNK="$2"; shift 2 ;;
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
MODERN="$DEST/modern"
LOG="$DEST/rescue.log"
STATE="$DEST/state.json"
PLAN_FILE="$DEST/plan.json"
VERIFY_FILE="$DEST/verification.json"
FONTS_JSON="$DEST/fonts.json"
FONTS_MD="$DEST/fonts.md"
RESOURCE_JSON="$DEST/resource-forks.json"

[[ -d "$SRC" ]] || { echo "Source not found: $SRC"; exit 1; }
mkdir -p "$DEST"

# Config dump
echo "=== Effective config ==="
echo "device: ${STARMAX_DEVICE:-none}"
echo "keep_patterns: ${STARMAX_KEEP_PATTERNS:-none}"
echo "junk: ${STARMAX_JUNK:-none}"
echo "thresholds: qxd=${STARMAX_QXD_THRESHOLD:-1} images=${STARMAX_IMAGE_THRESHOLD:-5} fonts=${STARMAX_FONT_THRESHOLD:-2}"
echo "notify: $NOTIFY"

log_json() {
  local level="$1" msg="$2"
  printf '{"ts":"%s","level":"%s","msg":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$msg" >> "$DEST/rescue.jsonl"
  echo "[$level] $msg"
}

exec > >(tee -a "$LOG") 2>&1
log_json info "start name=$NAME src=$SRC mode=$([[ $GO -eq 1 ]] && echo live || echo dry) plan=$PLAN"

# Shared classification function for plan + live
classify_item() {
  local base="$1"
  local qxd=0 fonts=0 images=0
  if [[ -d "$SRC/$base" ]]; then
    qxd=$(find "$SRC/$base" -type f -iname '*.qxd' 2>/dev/null | wc -l | tr -d ' ')
    fonts=$(find "$SRC/$base" -type f \( -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.ttf' -o -iname '*.otf' \) 2>/dev/null | wc -l | tr -d ' ')
    images=$(find "$SRC/$base" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pict' -o -iname '*.pct' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.gif' \) 2>/dev/null | wc -l | tr -d ' ')
  fi
  local action="review" reason="default"
  # patterns
  local matched=0
  for pat in "${KEEP_PATTERNS[@]:-}"; do
    # shellcheck disable=SC2254
    case "$base" in $pat) action="keepers"; reason="pattern:$pat"; matched=1; break ;; esac
  done
  if [[ $matched -eq 0 && $HEURISTICS -eq 1 ]]; then
    if [[ "$qxd" -ge ${STARMAX_QXD_THRESHOLD:-1} || "$fonts" -ge ${STARMAX_FONT_THRESHOLD:-2} || "$images" -ge ${STARMAX_IMAGE_THRESHOLD:-5} ]]; then
      action="keepers"
      reason="qxd=$qxd fonts=$fonts images=$images"
    fi
  fi
  # explicit junk
  for j in "${junk_names[@]:-}"; do
    [[ "$base" == "$j" ]] && action="_junk" && reason="explicit junk" && break
  done
  [[ "$base" == "Fonts" ]] && action="keepers" && reason="explicit Fonts"
  [[ "$base" == "Applications" ]] && action="_review" && reason="explicit Applications"
  echo "$action|$reason"
}

# Load patterns / junk early (needed for plan)
KEEP_PATTERNS=()
IFS=',' read -ra pats <<< "${STARMAX_KEEP_PATTERNS:-},${EXTRA_KEEP:-}"
for p in "${pats[@]}"; do [[ -n "$p" ]] && KEEP_PATTERNS+=("$p"); done
if [[ -f "$HOME/.starmax-keep" ]]; then
  while IFS= read -r line; do [[ -n "$line" && ! "$line" =~ ^# ]] && KEEP_PATTERNS+=("$line"); done < "$HOME/.starmax-keep"
fi

junk_names=( "Desktop DB" "Desktop DF" "Preferences" "Previous System Folder" "Extensions" "System Folder" )
IFS=',' read -ra ej <<< "${STARMAX_JUNK:-},${EXTRA_JUNK:-}"
for x in "${ej[@]}"; do [[ -n "$x" ]] && junk_names+=("$x"); done

# --- Accurate plan mode ---
if [[ $PLAN -eq 1 ]]; then
  python3 - "$SRC" "$PLAN_FILE" "$NAME" <<'PY'
import sys, json, time, subprocess, os
src, out, name = sys.argv[1:4]
plan = {"name": name, "generated": int(time.time()), "actions": []}
for entry in os.listdir(src):
    if entry.startswith('.') or entry in ("keepers","_junk","_review","full-extract","modern"): continue
    # call bash classify via env for simplicity; here we reimplement lightly
    plan["actions"].append({"item": entry, "action": "review", "reason": "see live run for exact"})
with open(out,"w") as f: json.dump(plan, f, indent=2)
print(f"Plan written (sketch; live uses full classify): {out}")
PY
  # Better: emit real plan from bash
  : > "$PLAN_FILE.tmp"
  echo "{" > "$PLAN_FILE"
  echo "  \"name\": \"$NAME\"," >> "$PLAN_FILE"
  echo "  \"generated\": $(date +%s)," >> "$PLAN_FILE"
  echo "  \"actions\": [" >> "$PLAN_FILE"
  first=1
  while IFS= read -r -d '' entry; do
    base=$(basename "$entry")
    result=$(classify_item "$base")
    action=${result%%|*}
    reason=${result#*|}
    [[ $first -eq 1 ]] && first=0 || echo "," >> "$PLAN_FILE"
    printf '    {"item":"%s","action":"%s","reason":"%s"}' "$base" "$action" "$reason" >> "$PLAN_FILE"
  done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  echo "" >> "$PLAN_FILE"
  echo "  ]" >> "$PLAN_FILE"
  echo "}" >> "$PLAN_FILE"
  log_json info "accurate plan written"
  echo "Plan: $PLAN_FILE"
  exit 0
fi

# Sanitize (skip root)
if [[ $SANITIZE -eq 1 && $GO -eq 1 ]]; then
  log_json info "sanitize start"
  find "$SRC" -mindepth 1 -depth -print0 2>/dev/null | while IFS= read -r -d '' p; do
    base=$(basename "$p")
    dir=$(dirname "$p")
    safe=$(printf '%s' "$base" | sed 's/[:\n\r]/_/g; s/^[[:space:]]*//; s/[[:space:]]*$//; s/Icon\n/Icon_/g; s/[^[:alnum:]._-]/_/g' | cut -c1-180)
    [[ "$base" == "$safe" || -z "$safe" ]] && continue
    [[ -e "$dir/$safe" ]] && safe="${safe}-$(date +%s)"
    mv -n "$p" "$dir/$safe" 2>/dev/null && log_json info "sanitized $base -> $safe" || true
  done || true
fi

# Clone
if [[ $CLONE -eq 1 ]]; then
  if [[ $GO -eq 1 ]]; then
    if [[ -d "$CLONE_DEST" ]]; then
      log_json info "full-extract exists, skipped"
    else
      mkdir -p "$CLONE_DEST"
      cp -a "$SRC"/. "$CLONE_DEST"/ && log_json info "cloned to full-extract"
    fi
  else
    log_json info "would clone to full-extract"
  fi
fi

do_move() {
  local item="$1" dest="$2"
  local srcpath="$SRC/$item"
  [[ -e "$srcpath" ]] || return 0
  if [[ $GO -eq 1 ]]; then
    mkdir -p "$dest"
    if [[ -e "$dest/$item" ]]; then
      log_json info "skip exists $item"
    else
      mv "$srcpath" "$dest/$item" && log_json info "moved $item -> $(basename "$dest")" || true
    fi
  else
    log_json info "would move $item -> $(basename "$dest")"
  fi
  return 0
}

# Classification using shared function
while IFS= read -r -d '' entry; do
  base=$(basename "$entry")
  [[ "$base" == keepers || "$base" == _junk || "$base" == _review || "$base" == full-extract || "$base" == modern ]] && continue
  result=$(classify_item "$base")
  action=${result%%|*}
  reason=${result#*|}
  case "$action" in
    keepers) do_move "$base" "$KEEP" || true; log_json info "classified keepers $base ($reason)" ;;
    _junk)   do_move "$base" "$JUNK" || true ;;
    *)       do_move "$base" "$REVIEW" || true ;;
  esac
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

[[ $GO -eq 0 ]] && { log_json info "dry-run complete"; exit 0; }

mkdir -p "$KEEP"

# Resource-fork / AppleDouble report
log_json info "resource-fork scan"
python3 - "$KEEP" "$RESOURCE_JSON" <<'PY' || true
import os, sys, json
from pathlib import Path
keep, out = sys.argv[1:3]
entries = []
for p in Path(keep).rglob("*"):
    if p.name.startswith("._") or p.name == ".DS_Store":
        entries.append({"path": str(p.relative_to(keep)), "type": "appledouble" if p.name.startswith("._") else "ds_store"})
with open(out, "w") as f: json.dump({"count": len(entries), "items": entries}, f, indent=2)
print(f"resource-forks.json: {len(entries)} items")
PY

# Type/creator
log_json info "type-creator scan"
python3 - "$KEEP" "$DEST/types.json" <<'PY' || true
import os, sys, json, subprocess
from pathlib import Path
keep, out = sys.argv[1:3]
entries = []
for p in Path(keep).rglob("*"):
    if not p.is_file() or p.name.startswith("._"): continue
    try:
        r = subprocess.run(["mdls", "-name", "kMDItemFSName", "-name", "kMDItemContentType", str(p)], capture_output=True, text=True, timeout=5)
        entries.append({"path": str(p.relative_to(keep)), "mdls": r.stdout.strip()[:300]})
    except Exception:
        pass
with open(out, "w") as f: json.dump(entries, f, indent=2)
print(f"types.json: {len(entries)} entries")
PY

# Export modern
if [[ $EXPORT_MODERN -eq 1 ]]; then
  log_json info "export-modern"
  mkdir -p "$MODERN"/{fonts,images,qxd,other}
  find "$KEEP" -type f -print0 | while IFS= read -r -d '' f; do
    base=$(basename "$f")
    [[ "$base" == ._* ]] && continue
    safe=$(printf '%s' "$base" | sed 's/[^[:alnum:]._-]/_/g' | cut -c1-150)
    lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
      *.ttf|*.otf|*.suit|*.dfont|*.bmap) dest="$MODERN/fonts/$safe" ;;
      *.qxd) dest="$MODERN/qxd/$safe" ;;
      *.jpg|*.jpeg|*.png|*.gif|*.tiff|*.tif|*.pict|*.pct) dest="$MODERN/images/$safe" ;;
      *) dest="$MODERN/other/$safe" ;;
    esac
    cp -n "$f" "$dest" 2>/dev/null || true
  done
  log_json info "modern export done"
fi

# Font inventory
log_json info "font inventory"
python3 - "$KEEP" "$MODERN" "$FONTS_JSON" "$FONTS_MD" <<'PY' || true
import os, sys, json, time
from pathlib import Path
keep, modern, jout, mdout = sys.argv[1:5]
fonts = []
exts = {".suit",".dfont",".bmap",".ttf",".otf",".woff",".woff2"}
for root in [keep, modern]:
    if not os.path.isdir(root): continue
    for p in Path(root).rglob("*"):
        if p.is_file() and p.suffix.lower() in exts and not p.name.startswith("._"):
            fonts.append({"name": p.name, "size": p.stat().st_size, "path": str(p.relative_to(root) if root == keep else p), "ext": p.suffix.lower()})
with open(jout, "w") as f: json.dump({"generated": int(time.time()), "count": len(fonts), "fonts": fonts}, f, indent=2)
with open(mdout, "w") as f:
    f.write(f"# Fonts ({len(fonts)})\n\n")
    for font in fonts:
        f.write(f"- {font['name']} ({font['ext']}, {font['size']} bytes)\n")
print(f"fonts.json / fonts.md: {len(fonts)} fonts")
PY

# Font conversion stub
if [[ $CONVERT_FONTS -eq 1 ]]; then
  log_json info "convert-fonts stub"
  mkdir -p "$MODERN/fonts"
  find "$KEEP" -type f \( -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.ttf' -o -iname '*.otf' \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
    base=$(basename "$f")
    safe=$(printf '%s' "$base" | sed 's/[^[:alnum:]._-]/_/g' | cut -c1-150)
    cp -n "$f" "$MODERN/fonts/$safe" 2>/dev/null || true
  done
  log_json info "fonts copied to modern/fonts (no format conversion)"
fi

# Verification + optional checksums
SRC_COUNT=$(find "$SRC" -type f 2>/dev/null | wc -l | tr -d ' ')
KEEP_COUNT=$(find "$KEEP" -type f 2>/dev/null | wc -l | tr -d ' ')
CLONE_COUNT=0
[[ -d "$CLONE_DEST" ]] && CLONE_COUNT=$(find "$CLONE_DEST" -type f 2>/dev/null | wc -l | tr -d ' ')

if [[ $VERIFY -eq 1 ]]; then
  log_json info "checksum verification"
  python3 - "$KEEP" "$VERIFY_FILE" "$SRC_COUNT" "$KEEP_COUNT" "$CLONE_COUNT" <<'PY'
import sys, json, time, hashlib
from pathlib import Path
keep, out, sc, kc, cc = sys.argv[1:6]
hashes = []
for p in Path(keep).rglob("*"):
    if p.is_file() and not p.name.startswith("._"):
        h = hashlib.sha256()
        try:
            with open(p, "rb") as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    h.update(chunk)
            hashes.append({"path": str(p.relative_to(keep)), "sha256": h.hexdigest()})
        except Exception:
            pass
with open(out, "w") as f:
    json.dump({"generated": int(time.time()), "source_files": int(sc), "keepers_files": int(kc), "full_extract_files": int(cc), "checksums": hashes}, f, indent=2)
print(f"verification.json with {len(hashes)} checksums")
PY
else
  python3 - "$VERIFY_FILE" "$SRC_COUNT" "$KEEP_COUNT" "$CLONE_COUNT" <<'PY'
import sys, json, time
out, sc, kc, cc = sys.argv[1:5]
with open(out, "w") as f:
    json.dump({"generated": int(time.time()), "source_files": int(sc), "keepers_files": int(kc), "full_extract_files": int(cc)}, f, indent=2)
print("verification.json written")
PY
fi
log_json info "verification source=$SRC_COUNT keepers=$KEEP_COUNT clone=$CLONE_COUNT"

# State
python3 - "$STATE" <<'PY'
import json, time, sys
with open(sys.argv[1], "w") as f:
    json.dump({"completed": int(time.time()), "status": "done"}, f)
PY

if [[ $NOTIFY -eq 1 ]]; then
  osascript -e "display notification \"Starmax rescue $NAME complete\" with title \"Starmax\"" 2>/dev/null || true
fi

log_json info "done"
echo "=== Done ==="
echo "Keepers: $KEEP"
[[ $CLONE -eq 1 ]] && echo "Full extract: $CLONE_DEST"
[[ $EXPORT_MODERN -eq 1 ]] && echo "Modern: $MODERN"
echo "Fonts: $FONTS_MD"
echo "Reports: $VERIFY_FILE $DEST/types.json $RESOURCE_JSON"
echo "Next: review _review/ and trash _junk/. ISO is master."
