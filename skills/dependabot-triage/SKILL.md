---
name: dependabot-triage
description: Triage and fix Dependabot vulnerability alerts in Node.js repos with prioritization framework, transitive override pattern, and version-pinning rules. Use when the user shares a Dependabot URL, asks to fix CVEs, or asks which vulnerability to pick first.
---

# Dependabot Triage & Fix

## How to install (one-time, per engineer)

Drop or symlink this directory into your Claude Code skills folder so the agent auto-loads it:

```bash
# Option A — symlink (stays in sync with this repo)
mkdir -p ~/.claude/skills
ln -s /home/<you>/tern-work/git-practices/skills/dependabot-triage ~/.claude/skills/dependabot-triage

# Option B — copy
cp -r /home/<you>/tern-work/git-practices/skills/dependabot-triage ~/.claude/skills/
```

Verify: in a new Claude Code session, the skill appears in `/skills` listing.

## How to invoke

Trigger phrases (any of these will route Claude Code to this skill):

- "Triage Dependabot alerts in `<repo>`"
- "Which vuln should I fix first? <github.com/.../security/dependabot URL>"
- "Fix Dependabot alert #<N> in this repo"
- "Bump `<pkg>` to a non-vulnerable version"

Provide one of:
- Dependabot security URL, OR
- Repo path + alert number(s), OR
- Just the package name if you already know the vuln.

## Prerequisites

- `gh` CLI authenticated with repo access (`gh auth status`).
- Local clone of the target repo (Claude needs to read `package.json` + lockfiles).
- `node`, `pnpm`, and/or `npm` installed for lockfile regeneration.
- Write permission to push a branch and open a PR (or accept that Claude stops at the commit step).

## What Claude will do

1. Fetch alerts via `gh api .../dependabot/alerts`, dedupe by package, rank using framework below.
2. For the top-ranked alert, read advisory details (`first_patched_version`, range).
3. Edit `package.json` to add an override.
4. Regenerate both lockfiles.
5. Verify resolved version.
6. Commit on a branch and open a PR (with explicit user OK before pushing).

## What Claude will NOT do without confirmation

- Bump a direct dependency across major versions (breaking).
- Delete or replace a package.
- Push to `main` / merge the PR.
- Skip pre-commit hooks.

## Prioritization framework

Three axes, in order:
1. **Impact** — RCE > data exfil/SSRF > DoS > logic bugs
2. **Reachability** — can attacker-controlled input hit the vuln code path? Webhook/HTTP-facing services magnify SSRF and any vuln in input parsers (XML, headers, glob).
3. **CVSS** — tiebreaker only. Raw score without reachability misleads (e.g. SSRF in axios shows 4.8 but matters more than a 7.5 dev-only ReDoS).

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
