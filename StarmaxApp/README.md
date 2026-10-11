# Starmax Mac App (skeleton)

Minimal SwiftUI front-end that wraps the existing CLI scripts.

## Current features
- Pick an extracted folder
- Run `rescue-cd.sh` with `--go --clone` (and optional `--convert-pict` / `--extract-sit`)
- Run `batch-rescue.sh` on a parent folder with `--only` pattern
- Live log output

## Build
Open `StarmaxApp.xcodeproj` in Xcode (or create one from the sources).
Requires macOS 14+.

The app expects the scripts to live next to it or on `$PATH`. For local testing it looks in `../scripts/` relative to the app bundle or the repo root.

This is a skeleton — enough to drive the hardened CLI without a terminal.
