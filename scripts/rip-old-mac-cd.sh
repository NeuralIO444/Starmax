#!/bin/bash
# rip-old-mac-cd.sh — Phase 1+2 hardened HFS CD rip + extract
# Incorporates prototype-run lessons (unique names, manual device preference, WH16NS40 notes).
#
# Usage: scripts/rip-old-mac-cd.sh [options] [name]
#
# Options:
#   -d, --device DEV     Force HFS device (e.g. /dev/disk4s1s2). Preferred when auto-detect is ambiguous.
#   -o, --outdir DIR     Archive dir (default: ~/cd-archive)
#   -n, --no-eject       Skip eject
#   --slow               More conservative ddrescue (extra retries, lower speed) for aged CDs
#   -v, --verbose
#   -h, --help
#
# Name optional (auto from volume or OldMacCD-<timestamp>). Must be unique — refuses to overwrite an existing ISO.
# Permanent ISO + .sha256 kept. Extracts to ~/Desktop/<name>/.
# Prefer ddrescue. For LG WH16NS40: use drutil status to confirm media before imaging.

set -euo pipefail

ARCHIVE_DIR="${HOME}/cd-archive"
LOG_DIR="${ARCHIVE_DIR}/logs"
FORCE_DEV=""
NO_EJECT=0
VERBOSE=0
SLOW=0
NAME=""

usage() { sed -n '2,24p' "$0" | sed 's/^# //'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device) FORCE_DEV="$2"; shift 2 ;;
    -o|--outdir) ARCHIVE_DIR="$2"; shift 2 ;;
    -n|--no-eject) NO_EJECT=1; shift ;;
    --slow) SLOW=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) NAME="$1"; shift ;;
  esac
done

mkdir -p "$ARCHIVE_DIR" "$LOG_DIR"
TS=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/rip-$TS.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== Starmax rip $TS ==="
echo "Log: $LOG"
echo "Tip: run 'drutil status' first to confirm the LG WH16NS40 sees media."

command -v impluse-hfs >/dev/null 2>&1 || { echo "ERROR: impluse-hfs missing. See README."; exit 1; }

# Device discovery (manual override preferred when multiple optical drives or nested slices)
if [[ -n "$FORCE_DEV" ]]; then
  HFS_DEV="$FORCE_DEV"
  CD_DISK=$(diskutil info "$HFS_DEV" 2>/dev/null | awk '/Part of Whole:/ {print $NF; exit}' || echo "unknown")
  echo "Forced device: $HFS_DEV (whole: $CD_DISK)"
else
  mapfile -t CANDIDATES < <(diskutil list | awk '
    /^\/dev\/ { d=$1; c=0 }
    /CD_partition_scheme|BD_partition_scheme|DVD_partition_scheme/ { c=1 }
    c && /Apple_HFS/ { print d, "/dev/" $NF }
    !c && /Apple_HFS/ { print d, "/dev/" $NF }
  ' | awk '!seen[$2]++')
  if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo "No HFS found."
    echo "1. Insert disc and click Ignore."
    echo "2. drutil status  (should show media, not 'No Media Inserted')"
    echo "3. diskutil list  (identify Apple_HFS slice by eye)"
    echo "4. Re-run with --device /dev/diskXsY"
    exit 1
  fi
  read -r CD_DISK HFS_DEV <<< "${CANDIDATES[0]}"
  echo "Detected: $HFS_DEV (on $CD_DISK)"
  [[ ${#CANDIDATES[@]} -gt 1 ]] && echo "Multiple candidates — prefer --device for the WH16NS40."
fi

[[ -z "$NAME" ]] && NAME="OldMacCD-$TS"
ISO="$ARCHIVE_DIR/$NAME.iso"

# Unique name enforcement (prototype lesson)
if [[ -e "$ISO" ]]; then
  echo "ERROR: $ISO already exists. Use a unique descriptive name."
  exit 1
fi

DEST="$HOME/Desktop/$NAME"
echo "Imaging $HFS_DEV -> $ISO"

if command -v ddrescue >/dev/null 2>&1; then
  echo "Using ddrescue"
  MAP="$ARCHIVE_DIR/$NAME.ddrescue.map"
  OPTS="-d -r3"
  [[ $SLOW -eq 1 ]] && OPTS="-d -r5 --max-read-rate=4M"
  sudo ddrescue $OPTS "$HFS_DEV" "$ISO" "$MAP" || echo "ddrescue finished with residual errors (map: $MAP)"
else
  echo "WARNING: ddrescue not found (brew install ddrescue). Using plain dd."
  sudo dd if="$HFS_DEV" of="$ISO" bs=2048 status=progress || { echo "dd failed"; exit 1; }
fi
sudo chown "$USER:$(id -gn)" "$ISO" 2>/dev/null || sudo chown "$USER" "$ISO"

echo "SHA-256..."
SHA=$(shasum -a 256 "$ISO" | awk '{print $1}')
echo "$SHA  $NAME.iso" > "$ISO.sha256"
echo "SHA-256: $SHA"

# Auto volume name (only if still default and no collision)
if [[ "$NAME" == OldMacCD-* ]]; then
  VOL=$(impluse-hfs list "$ISO" 2>/dev/null | awk -F' contains ' '/^\ud83d\udcbf / { gsub(/^\ud83d\udcbf /, "", $1); print $1; exit }' || true)
  if [[ -n "$VOL" ]]; then
    SAFE=$(printf '%s' "$VOL" | tr -cd '[:alnum:] ._-')
    if [[ -n "$SAFE" && ! -e "$ARCHIVE_DIR/$SAFE.iso" ]]; then
      mv "$ISO" "$ARCHIVE_DIR/$SAFE.iso"
      mv "$ISO.sha256" "$ARCHIVE_DIR/$SAFE.iso.sha256" 2>/dev/null || true
      ISO="$ARCHIVE_DIR/$SAFE.iso"
      DEST="$HOME/Desktop/$SAFE"
      NAME="$SAFE"
      echo "Auto-named from volume: $NAME"
    fi
  fi
fi

mkdir -p "$DEST"
echo "Extracting to $DEST"
ERR="$LOG_DIR/extract-$TS.err"
if impluse-hfs extract "$ISO" ':' >"$ERR" 2>&1; then
  echo "Full extract OK."
else
  echo "Full extract failed; resilient fallback (empty names / dupFNErr)."
  python3 - "$ISO" "$DEST" "$ERR" <<'PY'
import subprocess, sys, os, re, json
iso, dest, err = sys.argv[1:4]
out = subprocess.run(['impluse-hfs','list',iso], capture_output=True, text=True).stdout
vol, items, seen = None, [], set()
for line in out.splitlines():
    m = re.match(r'^\ud83d\udcbf (.+) contains \d+ items$', line)
    if m: vol = m.group(1); continue
    if vol and re.match(r'^ [\ud83d\udcc1\ud83d\udcc4] ', line):
        name = line[3:].split('\t')[0].split(' contains ')[0].strip()
        if name and name not in seen: seen.add(name); items.append(name)
if not items: sys.exit(1)
os.makedirs(dest, exist_ok=True); os.chdir(dest)
ok=bad=0; fails=[]
for name in items:
    r = subprocess.run(['impluse-hfs','extract',iso,f'{vol}:{name}'], capture_output=True, text=True)
    if r.returncode==0 or 'already exists' in (r.stdout+r.stderr): ok+=1
    else: bad+=1; fails.append({'name':name,'err':r.stderr[:300]}); print(f'FAIL: {name}')
print(f'{ok}/{len(items)} top-level OK')
if fails:
    with open(err+'.json','w') as f: json.dump(fails,f,indent=2)
    print('Failures:', err+'.json')
PY
fi

echo "Files extracted: $(find "$DEST" -type f 2>/dev/null | wc -l | tr -d ' ')"
echo "ISO (preservation master): $ISO"
echo "SHA: $SHA"
[[ $NO_EJECT -eq 0 ]] && diskutil eject "$CD_DISK" 2>/dev/null || true
echo "=== Complete. Log: $LOG ==="
