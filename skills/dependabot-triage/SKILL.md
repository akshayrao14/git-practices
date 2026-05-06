---
name: dependabot-triage
description: Triage and fix Dependabot vulnerability alerts in Node.js repos with prioritization framework, transitive override pattern, and version-pinning rules. Use when the user shares a Dependabot URL, asks to fix CVEs, or asks which vulnerability to pick first.
---

# Dependabot Triage & Fix

## How to install (one-time, per engineer)

Clone the repo anywhere, then run the bundled installer:

```bash
git clone https://github.com/akshayrao14/git-practices.git   # anywhere
bash git-practices/skills/dependabot-triage/install.sh
```

`install.sh` resolves its own location at run time and symlinks this folder into `~/.claude/skills/dependabot-triage` — works regardless of where the repo lives on disk. Override the target via `CLAUDE_SKILLS_HOME` if needed.

Restart your Claude Code session; the skill should appear in `/skills`. See `README.md` for uninstall + custom paths.

## How to invoke

Trigger phrases (any of these will route Claude Code to this skill):

- "Triage Dependabot alerts in `<repo>`"
- "Which vuln should I fix first? <github.com/.../security/dependabot URL>"
- "Fix Dependabot alert #<N> in this repo"
- "Bump `<pkg>` to a non-vulnerable version"

Provide one of:
- Repo-level Dependabot security URL (`github.com/<org>/<repo>/security/dependabot`), OR
- **Org-level** Dependabot security URL (`github.com/orgs/<org>/security/alerts/dependabot`) — Claude will fan-out across the org and rank cross-repo, OR
- Repo path + alert number(s), OR
- Just the package name if you already know the vuln.

## Prerequisites

- `gh` CLI authenticated with repo access (`gh auth status`).
- Local clone of the target repo (Claude needs to read `package.json` + lockfiles).
- `node`, `pnpm`, and/or `npm` installed for lockfile regeneration.
- Write permission to push a branch and open a PR (or accept that Claude stops at the commit step).

## What Claude will do

1. Fetch alerts:
   - Repo URL → `gh api repos/<org>/<repo>/dependabot/alerts?state=open&per_page=100`
   - Org URL → `gh api "orgs/<org>/dependabot/alerts?state=open&per_page=100"` (lists alerts across every repo in the org)

   Dedupe by `(repo, package)`, rank using frameworks below.
2. For the top-ranked alert, read advisory details (`first_patched_version`, range).
3. Confirm branching strategy AND base branch with user (see "Branching strategy" below). Detect default branch via `gh repo view --json defaultBranchRef`; never hardcode `main`. Default strategy: one PR per package, branched off latest `origin/<detected-base>`.
4. Edit `package.json` to add an override.
5. Regenerate both lockfiles.
6. Verify resolved version.
7. Commit on the branch and open a PR (with explicit user OK before pushing).

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

### Cross-repo / org-wide ranking

When the input is an org URL or spans multiple repos, apply two extra rules on top of the three axes above:

- **Group by `(repo, package)` first.** GitHub raises N alerts per `(repo, package)` pair when there are N CVEs against the same dep. Collapse them — one bump fixes the cluster.
- **Cluster bonus.** A `(repo, package)` pair with many alerts on an HTTP-facing service is the highest-ROI pick, even if individual CVSS scores are mid. Example: 30 axios alerts in a webhook service > 1 CVSS-9 alert in an internal CLI tool — single PR closes 30 alerts AND it's reachable.
- **Repo character matters.** HTTP/webhook ingest services magnify reachability for HTTP libs (axios, follow-redirects, fast-xml-parser). Frontend repos magnify XSS sanitizers (dompurify). Build-only deps (postcss in build chains) deprioritize.

Output a ranked table to the user: rank, repo, package, why-first, alerts-collapsed. Let user pick or accept default (rank 1).

## Branching strategy

**Default: one package per branch, one PR per branch.** Easier to review, easier to revert if a single override breaks something downstream.

### Determine the base branch dynamically

Do NOT hardcode `main`. The base may be `main`, `master`, `pre-release`, `develop`, etc. Detect at run time:

```bash
# Repo's configured default branch (preferred)
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name

# Fallback if gh unavailable
git symbolic-ref refs/remotes/origin/HEAD --short | sed 's@^origin/@@'
```

If the user has a different release flow (e.g. PRs target `pre-release`, then promoted to `main`), ASK them which branch this PR should target. Don't assume.

### Always branch from the latest remote base, not local

```bash
BASE=<detected-or-confirmed-base>
git fetch origin "$BASE"
git checkout -b <new-branch> "origin/$BASE"
```

Local copy of the base may be stale; branching off it pollutes the PR diff with drift from missed upstream commits.

### Strategy options — ask the user

Before starting, ask which strategy they want for this batch:
- (a) **One PR per package** (default) — atomic, clean revert
- (b) **One PR for multiple packages** — fewer PRs to review, but coupled revert
- (c) **Stack onto an existing branch / open PR** — useful if the prior PR is still open and the user wants to bundle

If user says "whatever's cleaner", pick (a).

## Workflow per alert

1. **Dedupe**: GitHub raises one alert per lockfile. `package-lock.json` + `pnpm-lock.yaml` = 2 alerts, 1 vuln. Fix package once.
2. **Get advisory**: `gh api repos/<org>/<repo>/dependabot/alerts/<n>` — extract `first_patched_version` and `vulnerable_range`. The list endpoint hides these.
3. **Locate**: direct dep (in `package.json`) or transitive? Find dependents:
   ```bash
   node -e "const l=require('./package-lock.json'); for(const[k,v]of Object.entries(l.packages||{}))if(v.dependencies?.['<pkg>']||v.devDependencies?.['<pkg>'])console.log(k,v.version);"
   ```
4. **Check direct usage**: `grep -r '<pkg>' --include='*.{js,ts,mjs}' -l | grep -v node_modules`. None = override-only fix, no code changes.
5. **Pick version**: latest in same major via `npm show <pkg> versions --json`. Confirm not behind a paywall of breaking changes.

   **Cluster shortcut**: when ≥3 alerts target the same `(repo, package)`, skip per-alert `first_patched_version` lookup. Just pick latest in same major (`npm show <pkg> version`) — the newest fix supersets older ones. Saves N round-trips and avoids picking a version that fixes some CVEs but not the latest.

## Override pattern (Node.js)

Use overrides for:
- **Transitive vulns** — package not in `dependencies`/`devDependencies`. Override is the only fix without bumping a parent.
- **Direct deps where transitives ALSO request the package** — bumping `dependencies.<pkg>` doesn't guarantee transitives get the same version (different semver ranges may hoist separately). Add the override anyway as defense-in-depth. Cheap belt-and-suspenders.

Dual-write to both override mechanisms if both lockfiles exist:

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
- **Conditional overrides rot.** If a prior conditional override exists (e.g. `"axios@<1.12.0": ">=1.12.0"`) and a new CVE range exceeds the prior cap, REPLACE the entry with a blanket `"axios": "^<latest>"`. Don't chain conditionals. Each new CVE batch tightens the floor; conditionals from a year ago are usually obsolete.

## Verify

```bash
node -e "const l=require('./package-lock.json'); console.log(l.packages['node_modules/<pkg>']?.version);"
grep -E '<pkg>@[0-9]' pnpm-lock.yaml | head -3
```

Both must show patched version.

**Don't trust install stdout.** `npm install --package-lock-only` may print `up to date` even when the override forced re-resolution and the lockfile actually changed. Same for pnpm in some edge cases. ALWAYS run the two verify commands above — they read the lockfile directly.

## Commit/PR format

- Title: `security: bump <pkg> to ^X.Y.Z (CVE-XXXX-YYYYY)`
- Body: link Dependabot alert numbers, name advisory (GHSA + CVE), state CVSS, explain dependent chain, note no source changes if override-only.

## After merge — UI lag

GitHub's Dependabot UI counts often lag the actual fix by 5–30 minutes. If the user reports "only N alerts closed, you predicted M" shortly after merge, don't assume the fix was incomplete. Verify via API first:

```bash
# Open axios alerts in this repo right now
gh api "repos/<org>/<repo>/dependabot/alerts?state=open&per_page=100" --jq '[.[] | select(.dependency.package.name=="<pkg>")] | length'

# Fixed-today list (sanity check the merge actually closed them)
gh api "repos/<org>/<repo>/dependabot/alerts?state=fixed&per_page=100" --jq '[.[] | select(.dependency.package.name=="<pkg>" and (.fixed_at | startswith("'"$(date -u +%Y-%m-%d)"'")))] | length'
```

If API confirms fix but UI still shows old count, reassure the user — it's UI lag, not a regression. The API is the source of truth. UI typically catches up within an hour after the lockfile push.
