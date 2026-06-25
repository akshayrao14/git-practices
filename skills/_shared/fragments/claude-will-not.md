## What Claude will NOT do without confirmation

- Bump a direct dependency across major versions (breaking).
- Apply a bump when changelog scrape flagged `BREAKING` / `DEPRECATED` / `MIGRATION` without a second user confirmation.
- Open the PR if the lockfile parity check failed (Standard OR Fast-Track).
- Skip dual-write override (mandatory in both modes).
- **Use Fast-Track for hard-ineligible cases** — `Public/API` import sites combined with CVSS ≥ 7.0, `critical` severity advisory, or a required cross-major bump. Fall back to Standard regardless of user request; the safety floor is non-overridable.
- Auto-fan-out across an org when the user only pasted a single repo URL (or vice versa).
- Delete or replace a package.
- Push to `main` / merge the PR.
- Skip pre-commit hooks.
