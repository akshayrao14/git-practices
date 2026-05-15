## v2.1 highlights

- **Two modes — Standard and Fast-Track.** Standard is the defensive workflow (full exposure mapping, changelog scrape, safety interlock). Fast-Track is for low-risk bumps (Internal/Dev category, CVSS < 7, or user opt-in) — skips changelog + detailed exposure enumeration, single-confirmation interlock. Parity check + dual-write are non-negotiable in BOTH modes.
- **CI workflow inspection — first-class detection step.** Lockfile alone doesn't tell you what runs in CI. CI may use a different PM than the committed lockfile (e.g. yarn.lock committed, CI runs `npm install`), or may run `<pm> install` instead of lockfile-strict `<pm> ci`. Detection drives the override + parity matrix.
- **Defensive versioning** — pick the *minimal* patched version that fixes all in-cluster CVEs, not "latest in same major".
- **Exposure Mapping** replaces heuristic reachability — categorize every import site (Public/API · Client-Bundle · Internal/Dev) and present surface area to the user instead of trying to prove unreachability.
- **Mandatory lockfile parity check** — every PM that touches the manifest must resolve to the *same* version of the target package; mismatch aborts the PR. Required because CI/CD often runs a different PM than local sanity checks.
- **Changelog scrape with safety interlock** (Standard mode) — fetch release notes / CHANGELOG between current and target, flag `BREAKING` / `DEPRECATED` / `MIGRATION` keywords, pause for explicit user confirmation before applying the bump.
- **Auto-reversion** — if Fast-Track fails parity or the build fails post-bump, the skill offers to switch back to Standard mode for deeper analysis instead of grinding on retries.
- **Org-level fan-out is opt-in only** — never auto-trigger; org enumeration burns API rate limit and surfaces non-JS noise.
