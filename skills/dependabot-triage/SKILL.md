---
name: dependabot-triage
description: Triage and fix Dependabot vulnerability alerts in Node.js repos with prioritization framework, transitive override pattern, and version-pinning rules.
---

# Dependabot Triage & Fix

## Prioritization framework

Three axes, in order:
1. **Impact** — RCE > data exfil/SSRF > DoS > logic bugs
2. **Reachability** — can attacker-controlled input hit the vuln code path? Webhook/HTTP-facing services magnify SSRF and any vuln in input parsers (XML, headers, glob).
3. **CVSS** — tiebreaker only. Raw score without reachability misleads (e.g. SSRF in axios shows 4.8 but matters more than a 7.5 dev-only ReDoS).

## Workflow per alert

1. **Dedupe**: GitHub raises one alert per lockfile. `package-lock.json` + `pnpm-lock.yaml` = 2 alerts, 1 vuln. Fix package once.
2. **Get advisory**: `gh api repos/<org>/<repo>/dependabot/alerts/<n>` — extract `first_patched_version` and `vulnerable_range`. The list endpoint hides these.
3. **Locate**: direct dep (in `package.json`) or transitive? Find dependents:
   ```bash
   node -e "const l=require('./package-lock.json'); for(const[k,v]of Object.entries(l.packages||{}))if(v.dependencies?.['<pkg>']||v.devDependencies?.['<pkg>'])console.log(k,v.version);"
   ```
4. **Check direct usage**: `grep -r '<pkg>' --include='*.{js,ts,mjs}' -l | grep -v node_modules`. None = override-only fix, no code changes.
5. **Pick version**: latest in same major via `npm show <pkg> versions --json`. Confirm not behind a paywall of breaking changes.

## Override pattern (Node.js)

For transitive vulns, dual-write to both override mechanisms if both lockfiles exist:

```json
{
  "pnpm": {
    "overrides": {
      "<pkg>": "^X.Y.Z"
    }
  },
  "overrides": {
    "<pkg>": "^X.Y.Z"
  }
}
```

Then: `pnpm install --no-frozen-lockfile` AND `npm install --package-lock-only`.

## Version range rules

- Use `^X.Y.Z` of `first_patched_version`, not `>=X.Y.Z`.
  - Same lower bound. Caps at `<next_major`. Prevent surprise major bump.
- Never `>X.Y.Z` — excludes the patched version itself, forces `X.Y.Z+1`, no benefit.
- For pnpm conditional override (vuln only in some range), use `<pkg>@<range>: <fix>` syntax, e.g. `"axios@<1.12.0": ">=1.12.0"`.

## Verify

```bash
node -e "const l=require('./package-lock.json'); console.log(l.packages['node_modules/<pkg>']?.version);"
grep -E '<pkg>@[0-9]' pnpm-lock.yaml | head -3
```

Both must show patched version.

## Commit/PR format

- Title: `security: bump <pkg> to ^X.Y.Z (CVE-XXXX-YYYYY)`
- Body: link Dependabot alert numbers, name advisory (GHSA + CVE), state CVSS, explain dependent chain, note no source changes if override-only.
