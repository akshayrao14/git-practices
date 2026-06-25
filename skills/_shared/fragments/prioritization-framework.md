## Prioritization framework

Three axes, in order:
1. **Impact** — RCE > data exfil/SSRF > DoS > logic bugs
2. **Exposure** — see Exposure Mapping below. NOT a heuristic guess about whether the vuln is reachable. A categorization of where the package is imported, presented to the user as a surface-area summary.
3. **CVSS** — tiebreaker only. Raw score without exposure context misleads (e.g. SSRF in axios shows 4.8 but matters more if axios is in Public/API).

> **CVSS=0 fallback.** Dependabot returns `security_advisory.cvss.score: 0` (or `null`) when the advisory hasn't been scored yet — common for fresh GHSAs. Don't let an unscored alert sink to the bottom of a CVSS-sorted ranking; fall back to `security_advisory.severity` (always populated). Approximate score mapping: `critical` ≈ 9.5, `high` ≈ 7.5, `medium` ≈ 5.0, `low` ≈ 2.0. Surface the fallback explicitly in the ranked table — e.g. `cvss: — (high)` rather than `cvss: 0` — so the user understands why a high-severity alert sits above a low-CVSS one.
