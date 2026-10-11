# Starmax

Rescue OS 9-era HFS CDs on a modern Mac. One pipeline, three steps:

1. **Rip** — image the disc to a bit-perfect `.iso` (`scripts/rip-old-mac-cd.sh`)
2. **Extract** — pull every file out of the HFS volume (same script, via impluse-hfs)
3. **Sort & archive** — one keepers folder, junk quarantined, keepers zipped,
   loot inventoried (`scripts/rescue-cd.sh`)

Built October 2026 while rescuing a stack of 1998–1999 design CDs.
macOS dropped HFS (not HFS+) in Catalina, so Finder just shows these discs
as "Uninitialized" — that's expected, not damage.

## One-time setup

- A USB CD/DVD drive (any ~$25 one; skip Apple's SuperDrive).
- [`impluse-hfs`](https://github.com/boredzo/impluse-hfs) built and installed:
  ```bash
  git clone https://github.com/boredzo/impluse-hfs.git ~/impluse-hfs
  cd ~/impluse-hfs
  xcodebuild -project impluse-hfs.xcodeproj -scheme impluse-hfs \
    -configuration Release build MACOSX_DEPLOYMENT_TARGET=12.0
  sudo cp <DerivedData>/Build/Products/Release/impluse-hfs /usr/local/bin/
  ```

## Usage

```bash
# 1. Insert the CD, click "Ignore" if macOS asks (never Initialize).
# 2. Rip + extract:
scripts/rip-old-mac-cd.sh "My CD Name"
# 3. Sort into keepers, archive, inventory the loot (dry run first):
scripts/rescue-cd.sh
scripts/rescue-cd.sh --go
```

`rescue-cd.sh` also works on any extracted folder:

```bash
scripts/rescue-cd.sh "/path/to/disc/extract" "My-Disc-Name" --go
```

Result in `~/Desktop/CD-Archive/<disc-name>/`:

| Folder / file | What it is |
|---|---|
| `keepers/` | Fonts, icons, docs, images — the good stuff, one folder |
| `_junk/` | Finder caches, prefs, dead OS parts — trash this yourself |
| `_review/` | Unknowns for you to eyeball |
| `<disc>-keepers.zip` | The archive |
| `loot-report.txt` | Every font, Quark doc, image, and possible email listed |

**Nothing is ever deleted by these scripts.** You trash `_junk/` in Finder
after reviewing it.

## Why not the obvious tools

- **Finder / Disk Utility**: can't read HFS since Catalina.
- **hfsutils** (`brew install hfsutils`): reads file *names* fine on Apple
  Silicon but reports all fork sizes as 0 — every extracted file comes out
  empty. Don't trust it here.
- **`dd` the slice, not the whole disc**: find the `Apple_HFS` identifier in
  `diskutil list` (e.g. `disk4s1s2`) and image that. Imaging the whole
  `/dev/disk4` also works but the nested partition map confuses some tools.

## Known unfixable edge cases

- Files with **empty filenames** on the disc can't exist on APFS. One of
  these kills a whole-volume extract — the rip script falls back to
  folder-by-folder automatically.
- **Duplicate names** that differ only in ways APFS normalizes (case, odd
  MacRoman chars) → `dupFNErr (-48)`. Extract the siblings individually.
- A file genuinely **0 bytes on the disc** (a failed 1999 burn) is just gone.
  `impluse-hfs list` shows real fork sizes, so you can tell these apart
  from tool failures.

## Opening the rescued files

- **QuarkXPress 3.x/4.x**: InDesign opens them directly via File → Open.
  For Quark 5+: Markzware Q2ID (paid).
- Old Photoshop/Illustrator files generally open in modern Adobe apps.
- `.sit` (StuffIt): The Unarchiver, or `unar` on the command line.
- Classic Mac font suitcases: extract the `POST` resources, reassemble to
  PFB, convert with FontForge → TTF. (Ask me, I've done this dance.)

## Roadmap

- [ ] One-button Mac app: pick the inserted disc, hit Rip, get a
      notification when the keepers zip lands on the Desktop.
- [ ] `ddrescue` instead of `dd` — retries scratched sectors on 28-year-old
      discs instead of dying on them.
- [ ] Read the disc's volume name automatically (no typing the disc name).
- [ ] PICT → PNG conversion in the loot pipeline.

## License

MIT. See [LICENSE](LICENSE).
