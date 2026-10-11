# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

**Phase 1** (hardening) + **Phase 2** (loot usefulness) are on `main`.

## Hardware notes
- **Preferred drive:** HL-DT-ST DVDRAM GP60NB60 (rev LI02) — more reliable on aged 1990s CDs than the WH16NS40.
- Secondary: LG HL-DT-ST BD-RE WH16NS40 (firmware 1.02).
- Confirm media with `drutil -drive 1 status` before imaging.
- "No Media Inserted" → eject, reinsert firmly, wait ~15 s, recheck. Still nothing → test a known-good disc or try the other drive.
- Prefer `--device` when multiple candidates appear; identify the Apple_HFS slice by eye if needed.
- ISO names must be unique. The .iso is the preservation master.

## One-time setup
- USB CD/DVD drive (GP60NB60 preferred).
- [`impluse-hfs`](https://github.com/boredzo/impluse-hfs) in `/usr/local/bin`.
- Recommended: `brew install ddrescue` and `brew install unar`.

## Usage

```bash
# Rip (unique name required if file exists)
scripts/rip-old-mac-cd.sh "My Disc"
# or auto-name, or --device /dev/diskXsY --slow

# Rescue (dry-run default)
scripts/rescue-cd.sh --src "~/Desktop/My Disc" --name "My-Disc" --go \
  --convert-pict --extract-sit
# heuristics on by default; --no-heuristics to disable
```

Results land in `~/Desktop/CD-Archive/<name>/`:
- `keepers/`, `_junk/`, `_review/`
- `loot-report.md` + `loot-report.json`
- `keepers.manifest.json` (sha256)
- `*-keepers.zip`
- logs

**Nothing is deleted.** Trash `_junk/` in Finder after review.

## Phase 2 features
- PICT/PCT → PNG side-by-side (`sips`, `--convert-pict`)
- Richer inventory: Markdown + JSON (fonts, QXD, images, archives, sizes, mtimes)
- Better font detection (suitcases, .bmap, rsrc hints)
- StuffIt extract via `unar` (`--extract-sit`, originals kept)
- Recursive heuristics on by default (content → keepers when fonts/QXD present)
- Keepers SHA-256 manifest
- GP60NB60 preferred; WH16NS40 noted; `--slow` for aged media
- Unique ISO name enforcement

## Prototype status (Oct 2026)
- Starmax.CD.22: done (ISO `~/quark-hfs.iso`)
- Starmax 4.Back-up.10/18/98: fully sorted, PICT converted, StuffIt extracted, zip refreshed
- Starmax 1: both HFS slices imaged successfully with GP60NB60 (`Starmax1-slice1-gp60.iso`, `Starmax1-slice2-gp60.iso`)

## Roadmap
- [x] Phase 1 hardening (ddrescue, SHA, logging, auto-name, robust fallback)
- [x] Phase 2 loot features
- [x] Prefer GP60NB60 hardware notes
- [ ] One-button Mac app
- [ ] Batch mode
- [ ] Font conversion helpers (beyond detection)

## License
MIT.
