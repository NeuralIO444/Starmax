# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

**Phase 1** + **Phase 2** are on `main`. Phase 3 work is starting on `phase3-start`.

## Hardware notes
- **Preferred drive:** HL-DT-ST DVDRAM GP60NB60 (rev LI02) — more reliable on aged 1990s CDs.
- Secondary: LG HL-DT-ST BD-RE WH16NS40 (firmware 1.02).
- Confirm media with `drutil -drive 1 status` before imaging.
- Prefer `--device` when multiple candidates appear.
- ISO names must be unique. The .iso is the preservation master.

## Usage

```bash
# Rip
scripts/rip-old-mac-cd.sh "My Disc"
# or --device /dev/diskXsY --slow

# Rescue with full clone (recommended) + sort
scripts/rescue-cd.sh --src "~/Desktop/My Disc" --name "My-Disc" --go --clone \
  --convert-pict --extract-sit
# heuristics on by default; --no-heuristics to disable
# --clone puts an unmodified copy in full-extract/ before any moves
```

Results land in `~/Desktop/CD-Archive/<name>/`:
- `full-extract/` (if --clone)
- `keepers/`, `_junk/`, `_review/`
- `loot-report.md` + `loot-report.json`
- `keepers.manifest.json` (sha256)
- `*-keepers.zip`
- logs

**Nothing is deleted.** Trash `_junk/` in Finder after review.

## Phase 3 (starting)
- [x] `--clone` mode (full unmodified copy of extract)
- [ ] Empty-keepers path no longer aborts the script
- [ ] One-button Mac app
- [ ] Batch mode
- [ ] Font conversion helpers

## Prototype status (Oct 2026)
- Starmax.CD.22: done
- Starmax 4.Back-up: fully processed
- Starmax 1: both slices imaged with GP60NB60, extracted, sorted

## License
MIT.
