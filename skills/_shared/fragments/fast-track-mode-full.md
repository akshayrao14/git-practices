## Fast-Track mode

A streamlined branch of the workflow for low-risk bumps. Trades changelog visibility and detailed exposure enumeration for velocity. Lockfile integrity is **not** sacrificed — dual-write override and parity check are still mandatory.

### Eligibility (any one is sufficient)

- **Dev-only exposure** — the lightweight import-site check shows ≥ 90% of sites in `Internal/Dev` (configs, scripts, tests, tooling) and zero sites in `Public/API`.
- **Low CVSS** — `security_advisory.cvss.score` < 7.0 *and* no Public/API import sites.
- **User opt-in** — the user explicitly says `"fast-track"`, `"just bump it"`, `"don't bother with the changelog"`, or similar.

If none apply, default to Standard mode.

### Hard ineligibility (no override — always Standard)

Fast-Track is refused — fall back to Standard with a one-line explanation — when:

- The package has any `Public/API` import sites AND CVSS ≥ 7.0.
- The advisory severity is `critical` (regardless of CVSS).
- A cross-major bump is required (defensive minimum sits in the next major).
- CI runs the PM's loose install command (not the lockfile-strict equivalent) without a committed lockfile for that PM. Every CI build re-resolves transitives fresh — the override field is the only pin on that side. Higher stakes; deserves Standard's full visibility. Also parity-check-ineligible: there's no committed lockfile to compare against.

These are non-overridable. If the user explicitly requests Fast-Track in one of these cases, refuse politely and run Standard mode — the safety floor isn't user-configurable.

### What Fast-Track skips

| Step | Standard | Fast-Track |
|---|---|---|
| Exposure Mapping (per-site enumeration) | Yes — full path listing per category | Skipped — single-line dominant category only |
| Changelog scrape | Yes — release notes + CHANGELOG.md, BREAKING/DEPRECATED/MIGRATION flagged | Skipped |
| Safety interlock | Two confirmations if breaking-change keywords flagged | Single confirmation |

### What Fast-Track keeps (non-negotiable)

| Step | Both modes |
|---|---|
| Defensive minimal-patched version | Yes |
| Dual-write override (see Override pattern) | Yes |
| Both-lockfile regeneration | Yes |
| Lockfile parity check + abort on mismatch | Yes |
| Commit + push gated on explicit user OK | Yes |

### Recommendation prompting

When presenting the ranked summary in step 5, include a Mode column or one-line recommendation:

```
Rank | Repo            | Package           | CVSS | Exposure (dominant) | Recommended mode
1    | webhook-ternity | @types/node       | 5.3  | Internal/Dev        | Fast-Track (Internal/Dev + low CVSS)
2    | webhook-ternity | axios             | 7.5  | Public/API          | Standard (hard-ineligible: Public/API + CVSS ≥ 7)
3    | webhook-ternity | follow-redirects  | 6.5  | Public/API          | Standard (Public/API exposure, no auto-rule fires; opt-in available)
```

Prompt verbatim where helpful: *"#1 is a dev-only @types bump with CVSS 5.3 — would you like to Fast-Track this fix?"*

Note: a Client-Bundle XSS-sanitizer package (e.g. `dompurify`, `sanitize-html`) at CVSS < 7.0 *will* trigger the auto Fast-Track rule per the eligibility table. Surface the recommendation but flag it: *"This is a sanitizer-class package on Client-Bundle — Fast-Track eligible by CVSS, but you may want Standard to see the changelog. Your call."* Defer to user.

### Auto-reversion on parity / build failure

Fast-Track skips analysis but does not paper over failures. If, after the bump:

- **Parity check fails** (npm and pnpm resolved to different versions), OR
- The user runs `pnpm build` / `npm test` and reports a failure, OR
- A pre-commit hook (lint, typecheck) fails

…then offer to switch back to Standard mode for the same package:

> *"Fast-Track hit `<failure>`. Want me to re-run this in Standard mode — pull the changelog and full exposure mapping so we can see what's actually changed?"*

Do not silently retry Fast-Track on the same package after a failure. Either escalate to Standard or stop and ask. Repeated Fast-Track retries on a failing bump is exactly the trap this mode is designed to avoid.
