# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

CLI-first. Phase 1 + Phase 2 + Phase 3 + features-next are the current path. Mac app skeleton remains on `mac-app-skeleton` (not required).

## First-run setup
```bash
cd /path/to/Starmax
chmod +x scripts/*.sh
```

## Hardware notes
- **Preferred drive:** HL-DT-ST DVDRAM GP60NB60 (rev LI02) — more reliable on aged 1990s CDs.
- Secondary: LG HL-DT-ST BD-RE WH16NS40.
- Confirm media with `drutil -drive 1 status` before imaging.
- Auto-detect is fragile — prefer `--device /dev/diskXsY` when multiple slices or drives appear.
- ISO names must be unique. The .iso is the preservation master.

## Typical CLI workflow

1. **Confirm the drive**
   ```bash
   drutil -drive 1 status
   diskutil list
   ```

2. **Rip (imaging + extract)**
   ```bash
   # Single candidate
   scripts/rip-old-mac-cd.sh "My-Disc-Name"

   # Multiple candidates — script lists them and exits; re-run with --device
   scripts/rip-old-mac-cd.sh --device /dev/disk4s1s2 "My-Disc-Name" --slow
   ```
   Produces a unique `.iso` + `.sha256` and extracts to `~/Desktop/<name>/`.

3. **Rescue (clone by default, then sort)**
   ```bash
   # Dry-run first (clone is on by default)
   scripts/rescue-cd.sh --src ~/Desktop/My-Disc-Name --name "My-Disc-Name"

   # Live
   scripts/rescue-cd.sh --src ~/Desktop/My-Disc-Name --name "My-Disc-Name" --go \
     --convert-pict --extract-sit
   ```
   Results in `~/Desktop/CD-Archive/<name>/`:
   - `full-extract/` (default)
   - `keepers/`, `_junk/`, `_review/`
   - reports, manifest, zip, logs

4. **Batch (optional)**
   ```bash
   scripts/batch-rescue.sh --only 'Starmax*' --skip-processed ~/Desktop/
   # or --dry-run to preview
   ```

**Nothing is deleted.** Trash `_junk/` in Finder after review. ISO stays the master.

## One-click paths (Shortcuts and Automator)

Both wrap the same CLI. Scripts stay the source of truth.

### Shortcuts app
1. Open Shortcuts → New Shortcut.
2. Add **Ask for Input** (or **Select File** / folder) → name it `Source Folder`.
3. Add **Run Shell Script**:
   ```bash
   cd /Users/mattciaglia/Dev/Starmax
   ./scripts/rescue-cd.sh --src "$1" --name "$(basename "$1")" --go --convert-pict --extract-sit
   ```
   Pass input as arguments.
4. Optional second Shortcut for rip:
   ```bash
   cd /Users/mattciaglia/Dev/Starmax
   ./scripts/rip-old-mac-cd.sh "$1"
   ```
   (Prompt for name or device separately if needed.)

Save and pin to the menu bar or share sheet.

### Automator Quick Action
1. Open Automator → New Document → Quick Action.
2. Set "Workflow receives current" to **folders** in **Finder**.
3. Add **Run Shell Script** action.
4. Shell: `/bin/bash`, Pass input: as arguments.
5. Script:
   ```bash
   cd /Users/mattciaglia/Dev/Starmax
   for f in "$@"; do
     name=$(basename "$f")
     ./scripts/rescue-cd.sh --src "$f" --name "$name" --go --convert-pict --extract-sit
   done
   ```
6. Save as "Starmax Rescue".

Right-click an extracted folder in Finder → Quick Actions → Starmax Rescue.

## Phase status
- [x] Clone by default (`--no-clone` to disable)
- [x] Broader heuristics + keep-pattern config
- [x] Batch dry-run and `--skip-processed`
- [x] Device candidate listing (rip script)
- [x] Sanitize and font stubs
- [ ] One-button Mac app (optional; skeleton on `mac-app-skeleton`)

## Prototype status (Oct 2026)
- Starmax.CD.22: done
- Starmax 4.Back-up: fully processed
- Starmax 1: both slices imaged with GP60NB60, extracted, sorted

## License
MIT.
