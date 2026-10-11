# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

**Phase 1** + **Phase 2** are on `main`. Phase 3 work is on `phase3-start`.

## Hardware notes
- **Preferred drive:** HL-DT-ST DVDRAM GP60NB60 (rev LI02).
- Secondary: LG HL-DT-ST BD-RE WH16NS40.
- Confirm media with `drutil -drive 1 status` before imaging.
- Prefer `--device` when multiple candidates appear.
- ISO names must be unique. The .iso is the preservation master.

## Usage

```bash
# Rip
scripts/rip-old-mac-cd.sh "My Disc"

# Single rescue with full clone
scripts/rescue-cd.sh --src "~/Desktop/My Disc" --name "My-Disc" --go --clone \
  --convert-pict --extract-sit

# Batch (folder of extracts)
scripts/batch-rescue.sh --clone --convert-pict ~/Desktop/Extracts/
```

Results land in `~/Desktop/CD-Archive/<name>/`:
- `full-extract/` (if --clone)
- `keepers/`, `_junk/`, `_review/`
- reports, manifest, zip, logs

Batch summary: `~/Desktop/CD-Archive/batch-summary.txt`

**Nothing is deleted.** Trash `_junk/` in Finder after review.

## Phase 3
- [x] `--clone` mode (full unmodified copy)
- [x] Empty-keepers path hardened
- [x] `batch-rescue.sh` wrapper
- [ ] One-button Mac app
- [ ] Font conversion helpers

## Prototype status (Oct 2026)
- Starmax.CD.22: done
- Starmax 4.Back-up: fully processed
- Starmax 1: both slices imaged with GP60NB60, extracted, sorted

## License
MIT.
