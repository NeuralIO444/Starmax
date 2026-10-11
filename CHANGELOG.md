# Changelog

## 2026-10-11 — Harden audit + docs

- Prefer GP60NB60 in rip script tips and diagnostics (`drutil -drive 1 status`).
- Heuristics now evaluated in dry-run so the plan is accurate.
- Batch summary files are timestamped.
- README refreshed; first-run `chmod +x` note added.
- Added `BUGS.md` and expanded opportunities section.

## 2026-10-11 — Phase 3

- `--clone` mode: full unmodified copy into `full-extract/` before sorting.
- Empty-keepers path no longer aborts the script.
- `batch-rescue.sh` with `--only` glob filter and automatic skip of the CD-Archive output directory.
- Mac app skeleton started on `mac-app-skeleton` branch.

## 2026-10-11 — Phase 2

- PICT/PCT → PNG side-by-side (`sips`).
- Markdown + JSON inventory.
- StuffIt extract via `unar` (originals kept).
- Recursive heuristics on by default (QXD / font counts → keepers).
- Keepers SHA-256 manifest.
- Unique ISO name enforcement and prototype-run diagnostics.

## 2026-10-11 — Phase 1

- Hardened rip and rescue scripts (logging, unique names, ddrescue preference, resilient extract fallback).
- Initial README and hardware notes from the prototype run.
