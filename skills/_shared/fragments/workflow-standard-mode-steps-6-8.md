### Standard mode (steps 6–8) — full defensive pipeline

6. **Exposure Mapping** — locate every import site of the target package in source, classify each into Public/API · Client-Bundle · Internal/Dev (see "Exposure Mapping" section). Output counts + sample paths.
7. **Changelog scrape** — fetch release notes / `CHANGELOG.md` between currently-installed and target version. Grep for `BREAKING`, `DEPRECATED`, `MIGRATION`, `removed`, `dropped support`. Surface flagged lines verbatim.
8. **Safety interlock — PAUSE.** Print the exposure summary + changelog flags + chosen target version to the user. Wait for explicit OK ("yes", "go", "looks fine", etc) before any file edits. If `BREAKING`/`DEPRECATED`/`MIGRATION` was flagged, require a second affirmative.
