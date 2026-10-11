# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

**Phase 1 + Phase 2 + Phase 3** are on `main`. Mac app skeleton is on `mac-app-skeleton`.

Full walkthroughs, format guides, and every failure mode hit so far:
**[Starmax wiki](https://github.com/NeuralIO444/Starmax/wiki)**.

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

After imaging, verify the rip before filing the disc away — the ISO timestamp
must be just now and the size plausible (~500–700 MB for a full CD):
`ls -lh ~/cd-archive/`. A stale timestamp means the image didn't write.

Results land in `~/Desktop/CD-Archive/<name>/`:
- `full-extract/` (if --clone)
- `keepers/`, `_junk/`, `_review/`
- reports, manifest, zip, logs

Batch summary is timestamped: `~/Desktop/CD-Archive/batch-summary-YYYYMMDD-HHMMSS.txt`

**Nothing is deleted.** Trash `_junk/` in Finder after review.

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
