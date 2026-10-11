# Starmax

Rescue OS 9-era HFS CDs on a modern Mac.

CLI-first with an optional modern TUI wizard. The `.iso` is the preservation master. Nothing is deleted automatically.

## Requirements

- macOS (tested on Apple Silicon)
- `drutil`, `diskutil`, `sips` (built-in)
- Optional but recommended:
  - `impluse-hfs` (for HFS extraction)
  - `ffmpeg` (better .mov poster frames)
  - `unar` (StuffIt extraction)
  - `rich` Python package (full TUI)

```bash
git clone https://github.com/NeuralIO444/Starmax.git
cd Starmax
chmod +x scripts/*.sh
pip install -r requirements.txt   # optional, for full TUI
# Optional config
cp example.starmax.toml ~/.starmax.toml
```

## Quick start (recommended)

```bash
python3 scripts/starmax-wizard.py
```

The wizard guides you through:
1. Insert disc
2. Detect drive
3. Name the archive
4. Options (sanitize, modern export, soft-convert icons, quick-view, etc.)
5. Rip + rescue

Results land in `~/Desktop/CD-Archive/<name>/`.

## Hardware notes

- **Preferred drive:** HL-DT-ST DVDRAM GP60NB60 (rev LI02) — more reliable on aged 1990s CDs.
- Other drives (e.g. LG WH16NS40) often work but may need tray cycling.
- Always confirm media:
  ```bash
  drutil -drive 1 status
  diskutil list
  ```
- Prefer explicit `--device /dev/diskXsY` when multiple slices appear.
- ISO filenames must be unique.

## Typical CLI workflow

1. **Confirm the drive**
   ```bash
   drutil -drive 1 status
   diskutil list
   ```

2. **Rip (imaging + extract)**
   ```bash
   scripts/rip-old-mac-cd.sh --device /dev/disk4s1s2 "My-Disc-Name" --slow
   ```
   Produces a unique `.iso` + `.sha256` and extracts to `~/Desktop/<name>/`.

3. **Rescue (clone by default, then sort)**
   ```bash
   # Dry-run / plan first
   scripts/rescue-cd.sh --src ~/Desktop/My-Disc-Name --name "My-Disc-Name" --plan

   # Live (recommended)
   scripts/rescue-cd.sh --src ~/Desktop/My-Disc-Name --name "My-Disc-Name" --go \
     --sanitize --export-modern --strip-icons --quick-view --notify
   ```

**Output structure** (`~/Desktop/CD-Archive/<name>/`):
- `full-extract/` — unmodified clone (default)
- `keepers/`, `_junk/`, `_review/`
- `modern/` — sanitized copies sorted into `fonts/`, `images/`, `qxd/`, `other/`
- `modern/previews/` — PICT→PNG and .mov poster frames (when `--quick-view`)
- `plan.json`, `verification.json`, `types.json`, `fonts.md`, `rescue.log`, `rescue.jsonl`

**Nothing is deleted.** Review `_review/` and trash `_junk/` yourself. The ISO stays the master.

## Key flags

| Flag | Purpose |
|------|---------|
| `--plan` | Write `plan.json` and exit (no changes). |
| `--sanitize` | Rename special characters / long names (safe; never renames the top-level source). |
| `--export-modern` | Copy keepers into `modern/{fonts,images,qxd,other}/` with clean names. |
| `--strip-icons` | Soft-convert: remove OS 9 custom icons so Finder shows modern defaults. |
| `--quick-view` | Generate PNG previews for PICT and poster frames for .mov. |
| `--convert-fonts` | Copy suitcase/.dfont/.ttf into `modern/fonts/` (copy-only; no format conversion). |
| `--verify` | SHA-256 checksums of keepers into `verification.json`. |
| `--notify` | macOS notification when finished. |
| `--no-clone` | Disable the default full unmodified copy. |
| `--no-heuristics` | Skip image/QXD/font heuristics. |

## Config file

Copy `example.starmax.toml` to `~/.starmax.toml`. Simple `key=value`:

```toml
preferred_device = "/dev/disk4s1s2"
keep_patterns = "Club*,Flyer*,*.qxd"
junk_names = "Desktop DB,Desktop DF,Extensions"
qxd_threshold = 1
image_threshold = 5
font_threshold = 2
notify = 1
```

## Known limitations & recovery

- **Drive flakiness**: Some USB optical drives (especially non-GP60) re-enumerate or show "Unsupported". Cycle the tray, unplug/replug, or switch drives. Prefer the GP60NB60 for old CDs.
- **Font conversion**: Currently copy-only into `modern/fonts/`. Real suitcase → TTF/OTF conversion requires external tools (not included).
- **Icon uprez**: No automatic conversion of custom OS 9 icons to modern high-res icons. `--strip-icons` removes them so Finder uses current system icons. Originals remain in the ISO / full-extract.
- **Multi-session / multi-slice discs**: Image each slice separately with unique ISO names. Use `diskutil list` to identify slices.
- **Partial rips**: If `dd` stalls, kill it (`sudo kill <pid>`), eject, reinsert, and retry with a new ISO name. The `.iso` is the master — re-extract from it if needed.
- **Dependencies**: Extraction needs `impluse-hfs`. StuffIt needs `unar`. Better movie previews need `ffmpeg`.

If a run fails halfway:
1. Check `rescue.log` and `rescue.jsonl` in the archive folder.
2. The `full-extract/` clone (if present) is a safe restart point.
3. Re-run with `--go` on the same source; existing destinations are skipped.

## Example walkthrough (GP60 drive)

```bash
# 1. Confirm media
drutil -drive 1 status

# 2. Rip a slice
scripts/rip-old-mac-cd.sh --device /dev/disk4s1s2 "MyDisc-slice1" --slow

# 3. Rescue with modern defaults
scripts/rescue-cd.sh --src ~/Desktop/MyDisc-slice1 --name "MyDisc-slice1" --go \
  --sanitize --export-modern --strip-icons --quick-view --notify

# 4. Review
open ~/Desktop/CD-Archive/MyDisc-slice1
```

Or just run the wizard and follow the prompts.

## One-click paths (Shortcuts and Automator)

Both wrap the same CLI. Scripts stay the source of truth.

### Shortcuts app
1. Open Shortcuts → New Shortcut.
2. Add **Ask for Input** (or **Select File** / folder) → name it `Source Folder`.
3. Add **Run Shell Script**:
   ```bash
   cd /path/to/Starmax
   ./scripts/rescue-cd.sh --src "$1" --name "$(basename "$1")" --go --export-modern --strip-icons --quick-view --notify
   ```
   Pass input as arguments.

### Automator Quick Action
1. Open Automator → New Document → Quick Action.
2. Set "Workflow receives current" to **folders** in **Finder**.
3. Add **Run Shell Script** action.
4. Shell: `/bin/bash`, Pass input: as arguments.
5. Script:
   ```bash
   cd /path/to/Starmax
   for f in "$@"; do
     name=$(basename "$f")
     ./scripts/rescue-cd.sh --src "$f" --name "$name" --go --export-modern --strip-icons --quick-view --notify
   done
   ```
6. Save as "Starmax Rescue".

Right-click an extracted folder in Finder → Quick Actions → Starmax Rescue.

## Batch (optional)

```bash
scripts/batch-rescue.sh --only 'Starmax*' --skip-processed ~/Desktop/
```

## License

MIT.
