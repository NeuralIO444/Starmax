# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

**Phase 1 + Phase 2 + Phase 3** are on `main`. Mac app skeleton is on `mac-app-skeleton`.

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

## Usage

```bash
# Rip (use --device when unsure)
scripts/rip-old-mac-cd.sh "My Disc"
# or --device /dev/disk4s1s2 --slow

# Single rescue with full clone
scripts/rescue-cd.sh --src "~/Desktop/My Disc" --name "My-Disc" --go --clone \
  --convert-pict --extract-sit

# Batch (only Starmax folders)
scripts/batch-rescue.sh --only 'Starmax*' --clone --convert-pict ~/Desktop/
```

Results land in `~/Desktop/CD-Archive/<name>/`:
- `full-extract/` (if --clone)
- `keepers/`, `_junk/`, `_review/`
- reports, manifest, zip, logs

Batch summary is timestamped: `~/Desktop/CD-Archive/batch-summary-YYYYMMDD-HHMMSS.txt`

**Nothing is deleted.** Trash `_junk/` in Finder after review.

## What I would do differently / opportunities

Now that the pipeline has been run against real 1998 discs:

- **Device detection** is still the weakest point. A small interactive picker (or mandatory `--device` prompt) would have saved time versus the fragile `awk` on `diskutil list`.
- **Clone-by-default** is the right call for preservation. Sorting should be an optional second pass rather than the primary behavior.
- **Heuristics** are useful but narrow (QXD + font count). Expanding to image-heavy folders, known project names, or a simple config file of keep patterns would catch more without manual review.
- **Special characters** (colons, leading spaces, `Icon\n`, long paths) still surface on old Mac volumes. A pre-sanitize or safer `mv`/`cp` wrapper would reduce failures.
- **Batch** is solid with `--only`, but a dry-run mode and a "skip already processed" check would make re-runs safer.
- **Mac app** skeleton exists; the highest-value next step is wiring it to the CLI so the common path is one button instead of terminal.
- **Font conversion** is still detection-only. Optional FontForge stubs (or a documented manual step) would complete the modernize checklist.
- **Verification** beyond SHA-256 of keepers (e.g., optional sector-level or file-count comparison against the ISO) would increase confidence on aged media.

See `CHANGELOG.md` and `BUGS.md` for the running record.

## Phase 3
- [x] `--clone` mode (full unmodified copy)
- [x] Empty-keepers path hardened
- [x] `batch-rescue.sh` with `--only` filter and CD-Archive skip
- [x] Dry-run evaluates heuristics
- [ ] One-button Mac app (skeleton on `mac-app-skeleton`)
- [ ] Font conversion helpers

## Prototype status (Oct 2026)
- Starmax.CD.22: done
- Starmax 4.Back-up: fully processed
- Starmax 1: both slices imaged with GP60NB60, extracted, sorted

## License
MIT.
