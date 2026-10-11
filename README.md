# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

CLI-first. Current path is `harden-all` (includes Phase 1–3 + features-next + hardening). Mac app skeleton remains on `mac-app-skeleton` (optional).

## First-run setup
```bash
cd /Users/mattciaglia/Dev/Starmax
chmod +x scripts/*.sh
# Optional config
cp example.starmax.toml ~/.starmax.toml
```

## Hardware notes
- **Preferred drive:** HL-DT-ST DVDRAM GP60NB60 (rev LI02) — more reliable on aged 1990s CDs.
- Secondary: LG HL-DT-ST BD-RE WH16NS40.
- Confirm media with `drutil -drive 1 status` before imaging.
- Prefer `--device /dev/diskXsY` when multiple slices or drives appear.
- ISO names must be unique. The `.iso` is the preservation master.

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

   # Live (recommended extras)
   scripts/rescue-cd.sh --src ~/Desktop/My-Disc-Name --name "My-Disc-Name" --go \
     --export-modern --notify
   ```
   Results in `~/Desktop/CD-Archive/<name>/`:
   - `full-extract/` (unmodified clone, default)
   - `keepers/`, `_junk/`, `_review/`
   - `modern/` (sanitized export into fonts/images/qxd/other when `--export-modern`)
   - `plan.json`, `verification.json`, `types.json`, `state.json`
   - `rescue.log` + `rescue.jsonl` (structured)
   - reports, manifest, zip

4. **Batch (optional)**
   ```bash
   scripts/batch-rescue.sh --only 'Starmax*' --skip-processed ~/Desktop/
   ```

**Nothing is deleted.** Trash `_junk/` in Finder after review. ISO stays the master.

## New flags (harden-all)

| Flag | Purpose |
|------|---------|
| `--plan` | Write `plan.json` (item + action + reason) and exit. No changes. |
| `--sanitize` | Pre-pass rename of special characters / long names (never renames the top-level source folder). |
| `--export-modern` | Copy keepers into `modern/{fonts,images,qxd,other}/` with sanitized names. |
| `--notify` | macOS notification when finished. |
| `--no-clone` | Disable the default full unmodified copy. |
| `--no-heuristics` | Skip image/QXD/font heuristics. |

### Config file
Copy `example.starmax.toml` to `~/.starmax.toml` (or `~/.starmax.conf`). Simple `key=value`:

```toml
preferred_device = "/dev/disk4s1s2"
keep_patterns = "Club*,Flyer*,*.qxd"
junk_names = "Desktop DB,Desktop DF,Extensions"
qxd_threshold = 1
image_threshold = 5
font_threshold = 2
notify = 1
```

## One-click paths (Shortcuts and Automator)

Both wrap the same CLI. Scripts stay the source of truth.

### Shortcuts app
1. Open Shortcuts → New Shortcut.
2. Add **Ask for Input** (or **Select File** / folder) → name it `Source Folder`.
3. Add **Run Shell Script**:
   ```bash
   cd /Users/mattciaglia/Dev/Starmax
   ./scripts/rescue-cd.sh --src "$1" --name "$(basename "$1")" --go --export-modern --notify
   ```
   Pass input as arguments.
4. Optional second Shortcut for rip:
   ```bash
   cd /Users/mattciaglia/Dev/Starmax
   ./scripts/rip-old-mac-cd.sh "$1"
   ```

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
     ./scripts/rescue-cd.sh --src "$f" --name "$name" --go --export-modern --notify
   done
   ```
6. Save as "Starmax Rescue".

Right-click an extracted folder in Finder → Quick Actions → Starmax Rescue.

## Phase status
- [x] Clone by default (`--no-clone` to disable)
- [x] Broader heuristics + keep-pattern config
- [x] Batch dry-run and `--skip-processed`
- [x] Device candidate listing (rip script)
- [x] Sanitize (safe pre-pass)
- [x] Plan mode (`--plan` → `plan.json`)
- [x] Export modern (`--export-modern`)
- [x] Structured logs (`rescue.jsonl`) + verification + types.json
- [x] Notification hook (`--notify` or config)
- [ ] One-button Mac app (optional; skeleton on `mac-app-skeleton`)

## Prototype status (Oct 2026)
- Starmax.CD.22: done
- Starmax 4.Back-up: fully processed
- Starmax 1: both slices imaged with GP60NB60, extracted, sorted (slice1 verified on harden-all)

## License
MIT.
