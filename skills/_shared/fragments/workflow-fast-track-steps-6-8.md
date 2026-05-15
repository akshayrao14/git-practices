### Fast-Track mode (steps 6–8) — low-risk shortcut

6. **Lightweight exposure check** — run the import-site grep ONCE to confirm the dominant Exposure category, but do NOT enumerate paths. Output: `Exposure: Internal/Dev (8 sites)`. Stops here; no per-category breakdown, no path listing.
7. **Skip changelog scrape.** (Fast-Track explicitly trades changelog visibility for speed; the eligibility rules below cap the blast radius this can cause.)
8. **Single-confirmation interlock — PAUSE.** Print: target version + dominant Exposure category + CVSS + reason for Fast-Track eligibility. One affirmative ("yes", "go", "ship it") moves on; anything ambiguous falls back to Standard.
