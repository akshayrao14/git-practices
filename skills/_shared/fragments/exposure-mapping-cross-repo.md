### Cross-repo / org-wide ranking (opt-in)

Only run when the user explicitly requested org fan-out. Apply on top of Impact × Exposure × CVSS:

- **Group by `(repo, package)` first.** GitHub raises N alerts per `(repo, package)` pair when there are N CVEs against the same dep. Collapse them — one bump fixes the cluster.
- **Cluster bonus.** A `(repo, package)` pair with many alerts on a Public/API repo is the highest-ROI pick, even if individual CVSS scores are mid. Example: 30 HTTP-client alerts in a webhook service > 1 CVSS-9 alert in an internal CLI tool — single PR closes 30 alerts AND it's high-exposure.
- **Repo character is a hint, not a verdict.** Backend/webhook repos *tend* to have Public/API import sites for HTTP libs; frontend repos *tend* to have Client-Bundle import sites for XSS sanitizers. Confirm via Exposure Mapping rather than assuming.

Output a ranked table: rank, repo, package, exposure summary (Public/API / Client-Bundle / Internal/Dev counts), alerts-collapsed. Let user pick or accept default (rank 1).
