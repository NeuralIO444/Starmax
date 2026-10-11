#!/bin/bash
# rescue-cd.sh — hardened with config, safer paths, verification, resume, plan mode, etc.
# Clone ON by default. Compatible with macOS bash 3.2.
#
# Usage: scripts/rescue-cd.sh [options] [src-dir] [name]
#
# Options:
#   --go --plan --no-clone --sanitize --export-modern --notify etc.
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
NOTIFY=${STARMAX_NOTIFY:-0}
EXTRA_KEEP=""
EXTRA_JUNK=""

usage() { sed -n '2,12p' "$0" | sed 's/^# //'; exit 0; }

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
VERIFY="$DEST/verification.json"

[[ -d "$SRC" ]] || { echo "Source not found: $SRC"; exit 1; }
mkdir -p "$DEST"

log_json() {
  local level="$1" msg="$2"
  printf '{"ts":"%s","level":"%s","msg":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$msg" >> "$DEST/rescue.jsonl"
  echo "[$level] $msg"
}

exec > >(tee -a "$LOG") 2>&1
log_json info "start name=$NAME src=$SRC mode=$([[ $GO -eq 1 ]] && echo live || echo dry) plan=$PLAN"

if [[ $PLAN -eq 1 ]]; then
  python3 - "$SRC" "$PLAN_FILE" "$NAME" <<'PY'
import os, sys, json, time
from pathlib import Path
src, out, name = sys.argv[1:4]
plan = {"name": name, "generated": int(time.time()), "actions": []}
for entry in Path(src).iterdir():
    if not entry.is_dir() and not entry.is_file(): continue
    base = entry.name
    if base in ("keepers", "_junk", "_review", "full-extract"): continue
    qxd = sum(1 for _ in entry.rglob("*.qxd")) if entry.is_dir() else 0
    images = sum(1 for p in entry.rglob("*") if p.suffix.lower() in {".jpg",".jpeg",".pict",".pct",".tiff",".tif",".gif"}) if entry.is_dir() else 0
    action = "review"
    reason = "default"
    if qxd >= 1 or images >= 5:
        action = "keepers"
        reason = f"qxd={qxd} images={images}"
    plan["actions"].append({"item": base, "action": action, "reason": reason})
with open(out, "w") as f: json.dump(plan, f, indent=2)
print(f"Plan written: {out} ({len(plan['actions'])} items)")
PY
  log_json info "plan written"
  exit 0
fi

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

KEEP_PATTERNS=()
IFS=',' read -ra pats <<< "${STARMAX_KEEP_PATTERNS:-},${EXTRA_KEEP:-}"
for p in "${pats[@]}"; do [[ -n "$p" ]] && KEEP_PATTERNS+=("$p"); done
if [[ -f "$HOME/.starmax-keep" ]]; then
  while IFS= read -r line; do [[ -n "$line" && ! "$line" =~ ^# ]] && KEEP_PATTERNS+=("$line"); done < "$HOME/.starmax-keep"
fi

junk_names=( "Desktop DB" "Desktop DF" "Preferences" "Previous System Folder" "Extensions" "System Folder" )
IFS=',' read -ra ej <<< "${STARMAX_JUNK:-},${EXTRA_JUNK:-}"
for x in "${ej[@]}"; do [[ -n "$x" ]] && junk_names+=("$x"); done

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

for i in "Fonts"; do do_move "$i" "$KEEP" || true; done
for i in "${junk_names[@]}"; do do_move "$i" "$JUNK" || true; done
for i in "Applications"; do do_move "$i" "$REVIEW" || true; done

while IFS= read -r -d '' entry; do
  base=$(basename "$entry")
  [[ "$base" == keepers || "$base" == _junk || "$base" == _review || "$base" == full-extract || "$base" == modern ]] && continue
  for pat in "${KEEP_PATTERNS[@]}"; do
    # shellcheck disable=SC2254
    case "$base" in $pat) do_move "$base" "$KEEP" || true; continue 2 ;; esac
  done
  if [[ $HEURISTICS -eq 1 ]]; then
    qxd=$(find "$SRC/$base" -type f -iname '*.qxd' 2>/dev/null | wc -l | tr -d ' ')
    fonts=$(find "$SRC/$base" -type f \( -iname '*.suit' -o -iname '*.dfont' -o -iname '*.bmap' -o -iname '*.ttf' \) 2>/dev/null | wc -l | tr -d ' ')
    images=$(find "$SRC/$base" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.pict' -o -iname '*.pct' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.gif' \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$qxd" -ge ${STARMAX_QXD_THRESHOLD:-1} || "$fonts" -ge ${STARMAX_FONT_THRESHOLD:-2} || "$images" -ge ${STARMAX_IMAGE_THRESHOLD:-5} ]]; then
      do_move "$base" "$KEEP" || true
      log_json info "heuristic keepers $base qxd=$qxd fonts=$fonts images=$images"
      continue
    fi
  fi
  do_move "$base" "$REVIEW" || true
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

[[ $GO -eq 0 ]] && { log_json info "dry-run complete"; exit 0; }

mkdir -p "$KEEP"

log_json info "type-creator scan"
python3 - "$KEEP" "$DEST/types.json" <<'PY' || true
import os, sys, json, subprocess
from pathlib import Path
keep, out = sys.argv[1:3]
entries = []
for p in Path(keep).rglob("*"):
    if not p.is_file(): continue
    try:
        r = subprocess.run(["mdls", "-name", "kMDItemFSName", "-name", "kMDItemContentType", str(p)], capture_output=True, text=True, timeout=5)
        entries.append({"path": str(p.relative_to(keep)), "mdls": r.stdout.strip()[:300]})
    except Exception:
        pass
with open(out, "w") as f: json.dump(entries, f, indent=2)
print(f"types.json: {len(entries)} entries")
PY

if [[ $EXPORT_MODERN -eq 1 ]]; then
  log_json info "export-modern"
  mkdir -p "$MODERN"/{fonts,images,qxd,other}
  find "$KEEP" -type f -print0 | while IFS= read -r -d '' f; do
    base=$(basename "$f")
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

SRC_COUNT=$(find "$SRC" -type f 2>/dev/null | wc -l | tr -d ' ')
KEEP_COUNT=$(find "$KEEP" -type f 2>/dev/null | wc -l | tr -d ' ')
CLONE_COUNT=0
[[ -d "$CLONE_DEST" ]] && CLONE_COUNT=$(find "$CLONE_DEST" -type f 2>/dev/null | wc -l | tr -d ' ')
python3 - "$VERIFY" "$SRC_COUNT" "$KEEP_COUNT" "$CLONE_COUNT" <<'PY'
import sys, json, time
out, sc, kc, cc = sys.argv[1:5]
with open(out, "w") as f:
    json.dump({"generated": int(time.time()), "source_files": int(sc), "keepers_files": int(kc), "full_extract_files": int(cc)}, f, indent=2)
print(f"verification.json written")
PY
log_json info "verification source=$SRC_COUNT keepers=$KEEP_COUNT clone=$CLONE_COUNT"

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
echo "Reports: $DEST/loot-report.* $VERIFY $DEST/types.json"
echo "Next: review _review/ and trash _junk/. ISO is master."
