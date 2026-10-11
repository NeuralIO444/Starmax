# Starmax

Rescue OS 9-era HFS CDs on a modern Mac (personal archive tool).

**Phase 1** (hardening) + **Phase 2** (loot usefulness) are on the `phase2` branch.

## Hardware notes (prototype run)
- LG HL-DT-ST BD-RE WH16NS40 (firmware 1.02) USB optical drive.
- Confirm media with `drutil status` before imaging (it sees the drive even when `diskutil` is quiet).
- "No Media Inserted" → eject, reinsert firmly, wait ~15 s, recheck. Still nothing → test a known-good disc.
- Prefer `--device` when multiple candidates appear; identify the Apple_HFS slice by eye if needed.
- ISO names must be unique. The .iso is the preservation master.

## One-time setup
- USB CD/DVD drive.
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
- WH16NS40-aware diagnostics and `--slow` for aged media
- Unique ISO name enforcement

## Prototype status (Oct 2026)
- Starmax.CD.22: done (ISO `~/quark-hfs.iso`)
- Starmax 4.Back-up.10/18/98: imaged (rename `CD Name.iso`), sort pending
- Starmax 1: unresolved ("No Media Inserted") — retest with known-good disc

## Roadmap
- [x] Phase 1 hardening (ddrescue, SHA, logging, auto-name, robust fallback)
- [x] Phase 2 loot features (this branch)
- [ ] One-button Mac app
- [ ] Batch mode
- [ ] Font conversion helpers (beyond detection)

## License
MIT.
