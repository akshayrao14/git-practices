## Prioritization framework

Three axes, in order:
1. **Impact** — RCE > data exfil/SSRF > DoS > logic bugs
2. **Exposure** — see Exposure Mapping below. NOT a heuristic guess about whether the vuln is reachable. A categorization of where the package is imported, presented to the user as a surface-area summary.
3. **CVSS** — tiebreaker only. Raw score without exposure context misleads (e.g. SSRF in axios shows 4.8 but matters more if axios is in Public/API).
