#!/bin/bash
# rip-old-mac-cd.sh — rescue an OS 9-era HFS CD to ~/Desktop
# Usage:  rip-old-mac-cd.sh "My CD Name"
#         (name is optional; defaults to OldMacCD-<timestamp>)
#
# One-time setup (already done on 2026-10-10):
#   - impluse-hfs built from https://github.com/boredzo/impluse-hfs
#     and installed to /usr/local/bin/impluse-hfs
#
# What it does:
#   1. Finds the Apple_HFS slice on the inserted CD (you click "Ignore"
#      when macOS asks about the disc)
#   2. dd's it to ~/cd-archive/<name>.iso  (the permanent archive — keep it)
#   3. Extracts everything to ~/Desktop/<name>/ with impluse-hfs
#      (falls back to folder-by-folder if one bad file kills the batch)
set -u

NAME="${1:-OldMacCD-$(date +%Y%m%d-%H%M)}"
ARCHIVE_DIR="$HOME/cd-archive"
ISO="$ARCHIVE_DIR/$NAME.iso"
DEST="$HOME/Desktop/$NAME"

command -v impluse-hfs >/dev/null 2>&1 || {
  echo "impluse-hfs not found. Build it once:"
  echo "  git clone https://github.com/boredzo/impluse-hfs.git ~/impluse-hfs"
  echo "  cd ~/impluse-hfs && xcodebuild -project impluse-hfs.xcodeproj \\"
  echo "    -scheme impluse-hfs -configuration Release build MACOSX_DEPLOYMENT_TARGET=12.0"
  echo "  sudo cp <DerivedData>/Build/Products/Release/impluse-hfs /usr/local/bin/"
  exit 1
}

# --- 1. locate the HFS slice on the CD -------------------------------------
read -r CD_DISK HFS_DEV <<< "$(diskutil list | awk '/^\/dev\//{d=$1; c=0} /CD_partition_scheme/{c=1} c && /Apple_HFS/{print d, "/dev/" $NF; exit}')"
if [ -z "${HFS_DEV:-}" ]; then
  echo "No HFS CD found."
  echo "Insert the disc, click 'Ignore' if macOS asks, and try again."
  echo "(If it's a plain ISO-9660 CD it should just mount in Finder by itself.)"
  exit 1
fi
echo "Found HFS volume: $HFS_DEV  (on $CD_DISK)"

# --- 2. image it (the permanent archive) ------------------------------------
mkdir -p "$ARCHIVE_DIR"
echo "Imaging to $ISO — takes a few minutes, leave the drive alone..."
sudo dd "if=$HFS_DEV" "of=$ISO" bs=2048
sudo chown "$USER" "$ISO"
echo "Archive saved: $ISO ($(du -h "$ISO" | cut -f1))"

# --- 3. extract --------------------------------------------------------------
mkdir -p "$DEST"
cd "$DEST"
echo "Extracting to $DEST ..."
if impluse-hfs extract "$ISO" ':' 2>/tmp/impluse-err.txt; then
  echo "Done — full volume extracted."
else
  echo "Whole-volume extract hit a bad file; falling back to folder-by-folder..."
  tail -3 /tmp/impluse-err.txt
  python3 - "$ISO" "$DEST" <<'PYEOF'
import subprocess, sys, os, re
iso, dest = sys.argv[1], sys.argv[2]
out = subprocess.run(['impluse-hfs', 'list', iso],
                     capture_output=True, text=True).stdout
vol, items, seen = None, [], set()
for line in out.splitlines():
    m = re.match(r'^💿 (.+) contains \d+ items$', line)
    if m:
        vol = m.group(1)
        continue
    if vol and re.match(r'^ [📁📄] ', line):
        name = line[3:]
        if ' contains ' in name:
            name = name.split(' contains ')[0]
        else:
            name = name.split('\t')[0]
        if name not in seen:
            seen.add(name)
            items.append(name)
os.chdir(dest)
ok, bad = 0, []
for name in items:
    r = subprocess.run(['impluse-hfs', 'extract', iso, f"{vol}:{name}"],
                       capture_output=True, text=True)
    if r.returncode == 0 or 'already exists' in (r.stdout + r.stderr):
        ok += 1
    else:
        bad.append(name)
print(f"Top-level items extracted: {ok}/{len(items)}")
if bad:
    print("These need manual attention (bad filenames on the disc):")
    for b in bad:
        print(f"  - {b}")
PYEOF
fi

echo "Files in $DEST: $(find "$DEST" -type f | wc -l | tr -d ' ')"
echo "Archive kept at: $ISO"
diskutil eject "$CD_DISK" 2>/dev/null || true
echo "CD ejected. Done."
