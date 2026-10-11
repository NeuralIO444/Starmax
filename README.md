# Starmax

Rescue OS 9-era HFS CDs on a modern Mac. Hardened Phase 1 pipeline:

1. **Rip** — bit-perfect ISO (prefer `ddrescue`) + SHA-256 + extract (`scripts/rip-old-mac-cd.sh`)
2. **Extract** — full or resilient folder-by-folder fallback via `impluse-hfs`
3. **Sort & archive** — configurable keepers / junk / review, zip, loot report (`scripts/rescue-cd.sh`)

Built October 2026 for 1998–1999 design CDs. macOS (Catalina+) shows HFS as "Uninitialized" — expected.

## One-time setup

- USB CD/DVD drive.
- [`impluse-hfs`](https://github.com/boredzo/impluse-hfs) built and in `/usr/local/bin`.
- Optional but recommended: `brew install ddrescue` (retries on scratched discs).

```bash
git clone https://github.com/boredzo/impluse-hfs.git ~/impluse-hfs
cd ~/impluse-hfs
xcodebuild -project impluse-hfs.xcodeproj -scheme impluse-hfs \
  -configuration Release build MACOSX_DEPLOYMENT_TARGET=12.0
sudo cp <DerivedData>/Build/Products/Release/impluse-hfs /usr/local/bin/
```

## Usage (Phase 1)

```bash
# Rip (auto-detect disc, optional name; uses ddrescue if present)
scripts/rip-old-mac-cd.sh "My Disc"
# or fully auto:
scripts/rip-old-mac-cd.sh

# Rescue (dry-run default; --go to execute)
scripts/rescue-cd.sh --src "~/Desktop/My Disc" --name "My-Disc" --go
# or with extras:
scripts/rescue-cd.sh --src /path --keep "Icons,Docs" --junk "Cache" --go
```

Results:
- ISO + `.sha256` + logs in `~/cd-archive/` (and `logs/`)
- Extract + sorted archive in `~/Desktop/CD-Archive/<name>/`
  - `keepers/`, `_junk/`, `_review/`, `*-keepers.zip`, `loot-report.txt`, `rescue.log`

**Nothing is deleted.** Review then trash `_junk/` yourself.

## Hardening (Phase 1)

- Prefer `ddrescue` with mapfile and retries; fallback to `dd` with progress.
- SHA-256 of every ISO.
- Timestamped logs (rip + extract errors + rescue).
- Robust device discovery (CD scheme preferred, `--device` override).
- Auto volume-name detection for ISO/dest when name omitted.
- Resilient extraction fallback (per top-level item, JSON failure log).
- Configurable classification (`--keep`/`--junk`, env `STARMAX_KEEP`/`STARMAX_JUNK`).
- Cleaner argument parsing, dry-run by default, no hardcoded personal paths.
- `set -euo pipefail` + better ownership and error paths.

## Why not the obvious tools

- Finder/Disk Utility: no HFS since Catalina.
- `hfsutils`: empty files on Apple Silicon.
- Plain `dd` of whole disc confuses some tools; we target the HFS slice.

## Known edge cases

- Empty filenames kill full extract → automatic folder fallback.
- Case/MacRoman duplicates → `dupFNErr`; extract individually.
- True 0-byte files on disc are unrecoverable (`impluse-hfs list` shows real sizes).

## Opening rescued files

- Quark 3/4 `.qxd` → InDesign File → Open. Quark 5+ needs Markzware.
- Old PS/AI generally open in modern Adobe.
- `.sit` → The Unarchiver or `unar`.
- Font suitcases → extract POST, FontForge → TTF.

## Roadmap

- [x] `ddrescue` preference + retries
- [x] Auto volume name
- [x] SHA-256 + logging + robust discovery
- [x] Configurable classification + better parsing
- [ ] PICT → PNG in pipeline
- [ ] One-button Mac app (SwiftUI front-end over hardened CLI)
- [ ] Batch mode + recursive heuristics
- [ ] Font conversion helpers

## License

MIT. See [LICENSE](LICENSE).
