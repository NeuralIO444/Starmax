# Known issues and limitations

## Open

- **Device auto-detect is fragile.** The `awk` parse of `diskutil list` can pick the wrong slice or fail when multiple optical devices or nested Apple_HFS partitions exist. Workaround: always use `--device /dev/diskXsY` after confirming with `drutil -drive 1 status` and `diskutil list`.
- **Special characters in old Mac names.** Colons, leading/trailing spaces, `Icon\n`, and very long paths can cause `mv`/`cp`/`find` failures or "File name too long" errors. Clone mode and the resilient extract fallback mitigate some cases; a pre-sanitize step is still missing.
- **Heuristics are narrow.** Only QXD count ≥ 1 or font-like files ≥ 2 promote a folder to keepers. Image-heavy or custom-named project folders often land in `_review/` and require manual promotion.
- **Scripts are not executable in git.** After clone/pull you must `chmod +x scripts/*.sh`. (Mode is stored as 100644.)
- **Manifest loads full files into memory.** Fine for typical CD sizes; could OOM on unusually large extracts.
- **Zip only covers keepers.** `full-extract/` is not archived by default.
- **Mac app skeleton is incomplete.** It exists on `mac-app-skeleton` but is not yet a one-button buildable app.
- **Font conversion is detection-only.** No FontForge or other conversion stubs yet.

## Fixed in this series

- Empty-keepers path no longer aborts the script (Phase 3).
- Batch no longer recursively clones the CD-Archive output directory (Phase 3 + `--only`).
- Unique ISO name enforcement (Phase 1).
- Dry-run now shows heuristic decisions (harden-audit).

## Opportunities

See the "What I would do differently" section in the README for the prioritized list.
