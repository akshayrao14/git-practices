---
name: dependabot-triage
description: Triage and fix Dependabot vulnerability alerts in JavaScript/TypeScript repos (Node.js services AND browser frontends). v2.1 workflow — defensive minimal-patched versioning, exposure mapping (Public/API · Client-Bundle · Internal/Dev), mandatory lockfile parity check between npm and pnpm, changelog scrape with BREAKING/DEPRECATED/MIGRATION flagging, and safety interlock before applying bumps. Covers npm, pnpm, yarn, bun lockfiles. Use when the user shares a Dependabot URL, asks to fix CVEs, or asks which vulnerability to pick first.
---

# Dependabot Triage & Fix (v2.1)

## v2.1 highlights

- **Defensive versioning** — pick the *minimal* patched version that fixes all in-cluster CVEs, not "latest in same major".
- **Exposure Mapping** replaces heuristic reachability — categorize every import site (Public/API · Client-Bundle · Internal/Dev) and present surface area to the user instead of trying to prove unreachability.
- **Mandatory lockfile parity check** — `package-lock.json` and `pnpm-lock.yaml` must resolve to the *same* version of the target package; mismatch aborts the PR. Required because CI/CD runs npm while local sanity checks run pnpm.
- **Changelog scrape with safety interlock** — fetch release notes / CHANGELOG between current and target, flag `BREAKING` / `DEPRECATED` / `MIGRATION` keywords, pause for explicit user confirmation before applying the bump.
- **Org-level fan-out is opt-in only** — never auto-trigger; org enumeration burns API rate limit and surfaces non-JS noise.

## Scope

**Only JavaScript / TypeScript repos** — npm, pnpm, yarn, bun ecosystems. Covers backend Node.js services, frontend bundles (CSR), server-rendered apps (SSR), and mixed SSR+CSR frameworks (Next.js, Nuxt, Remix, SvelteKit).

**NOT yet covered**: Python (pip / poetry / uv), Go modules, Java (Maven / Gradle), Ruby (bundler), Rust (cargo), .NET (NuGet). If the user shares a Dependabot URL pointing to a repo whose alerts are non-JS (check `.dependency.package.ecosystem`), say so explicitly and stop — don't apply this skill's mechanics to those ecosystems.

The org-level fan-out *will* surface non-JS alerts (e.g. Python `pillow`, Java packages). Filter those out of the ranked table or call them out as "out of scope for this skill — handle separately".

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
- Repo path + alert number(s), OR
- Just the package name if you already know the vuln.

**Org-level fan-out is opt-in only.** Even if the user pastes an org URL (`github.com/orgs/<org>/security/alerts/dependabot`), do NOT auto-enumerate the entire org. Confirm first: "This will paginate alerts across every repo in the org and may use significant API rate limit. Proceed?" Then run only on `yes`. The trigger phrases for explicit org fan-out:
- "Fan out across the org"
- "Triage all repos in `<org>`"
- "Run org-wide triage"

## Prerequisites

- `gh` CLI authenticated with repo access (`gh auth status`).
- Local clone of the target repo (Claude needs to read `package.json` + lockfiles).
- `node`, `pnpm`, and/or `npm` installed for lockfile regeneration.
- Write permission to push a branch and open a PR (or accept that Claude stops at the commit step).

## What Claude will do (v2.1 workflow)

1. **Fetch alerts**:
   - Repo URL → `gh api "repos/<org>/<repo>/dependabot/alerts?state=open&per_page=100"`
   - Org URL → only after explicit user confirmation, then `gh api "orgs/<org>/dependabot/alerts?state=open&per_page=100"` (paginates across every repo).
   - Filter `.dependency.package.ecosystem == "npm"` for this skill; surface non-JS alerts as out-of-scope.
   - Dedupe by `(repo, package)`.
2. **Rank** using the prioritization framework (Impact × Exposure × CVSS).
3. **Read advisory** for the top pick — extract `first_patched_version` and `vulnerable_version_range`. For clusters, compute the *minimal* version that supersets every CVE patch.
4. **Exposure Mapping** — locate every import site of the target package in source, classify each into Public/API · Client-Bundle · Internal/Dev (see "Exposure Mapping" section). Output counts + sample paths.
5. **Changelog scrape** — fetch release notes / `CHANGELOG.md` between currently-installed and target version. Grep for `BREAKING`, `DEPRECATED`, `MIGRATION`, `removed`, `dropped support`. Surface flagged lines verbatim.
6. **Safety interlock — PAUSE.** Print the exposure summary + changelog flags + chosen target version to the user. Wait for explicit OK ("yes", "go", "looks fine", etc) before any file edits. If `BREAKING`/`DEPRECATED`/`MIGRATION` was flagged, require a second affirmative.
7. **Confirm branching strategy AND base branch.** Detect default branch via `gh repo view --json defaultBranchRef`; never hardcode `main`. Default: one PR per package off latest `origin/<detected-base>`.
8. **Edit `package.json`** — dual-write both `pnpm.overrides` AND top-level `overrides` (mandatory; see "Override pattern").
9. **Regenerate BOTH lockfiles** — `pnpm install --no-frozen-lockfile` AND `npm install --package-lock-only`. No "primary" lockfile; both must be regenerated.
10. **Parity check** — read both lockfiles and assert they resolved to the *same* version of the target package. Mismatch → abort PR (see "Verify (Parity Check)").
11. **Commit on the branch and open a PR** — with explicit user OK before pushing.

## What Claude will NOT do without confirmation

- Bump a direct dependency across major versions (breaking).
- Apply a bump when changelog scrape flagged `BREAKING` / `DEPRECATED` / `MIGRATION` without a second user confirmation.
- Open the PR if the lockfile parity check failed.
- Auto-fan-out across an org when the user only pasted a single repo URL (or vice versa).
- Delete or replace a package.
- Push to `main` / merge the PR.
- Skip pre-commit hooks.

## Prioritization framework

Three axes, in order:
1. **Impact** — RCE > data exfil/SSRF > DoS > logic bugs
2. **Exposure** — see Exposure Mapping below. NOT a heuristic guess about whether the vuln is reachable. A categorization of where the package is imported, presented to the user as a surface-area summary.
3. **CVSS** — tiebreaker only. Raw score without exposure context misleads (e.g. SSRF in axios shows 4.8 but matters more if axios is in Public/API).

## Exposure Mapping

Replaces the prior heuristic "reachability" model. Goal: stop trying to PROVE a vuln is unreachable — false negatives are dangerous. Instead, enumerate every import site of the target package and bucket each one. The user makes the final risk call from the surface area.

### Categories

| Category | Definition | Example file paths |
|---|---|---|
| **Public/API** | Code that serves HTTP/RPC/webhook traffic from outside the trust boundary. Attacker-controlled input flows in. | `handlers/`, `routes/`, `controllers/`, `app/api/**/route.{ts,js}`, `pages/api/**`, `middleware.{ts,js}`, `+server.{ts,js}`, `+page.server.{ts,js}`, Lambda entry handlers, Express/Fastify route definitions |
| **Client-Bundle** | Code that ships in the browser bundle. Reachable via XSS / DOM injection / malicious user content rendered to the browser. | `src/components/**`, `src/app/**/{page,layout,loading,error}.{ts,tsx}` (no `.server.` suffix), `src/pages/**` (Next.js classic), Vue/Svelte component files, anything imported into a `<script>`-shipped entry. |
| **Internal/Dev** | Build, tooling, scripts, tests, configs. Does NOT run in prod request path or ship to browsers. | `vite.config.*`, `next.config.*`, `*.config.{js,ts,mjs}`, `scripts/`, `tests/`, `**/*.test.*`, `**/*.spec.*`, `.husky/`, `.cicd/`, `tools/`, `bin/` (CLI scripts) |

### How to enumerate import sites

Prefer ripgrep (fast, respects `.gitignore`):

```bash
# Find every import site of <pkg>
rg -t js -t ts "from ['\"]<pkg>(/|['\"])|require\(['\"]<pkg>(/|['\"])" -l | sort -u
```

Fallback to grep:

```bash
grep -rE "from ['\"]<pkg>['\"]|require\(['\"]<pkg>['\"]\)" \
  --include='*.{js,jsx,ts,tsx,mjs,cjs,mts,cts,vue,svelte}' -l | grep -v node_modules
```

Then bucket each path by matching against the table above. Paths that don't fit cleanly → ask the user, do not guess.

### How to present to the user

Output as a surface summary, not a verdict:

```
Exposure surface for axios in webhook-ternity:
  Public/API     : 12 sites (e.g. handlers/getAllCandidates.js, handlers/public/idMetadata.js, ...)
  Client-Bundle  : 0 sites
  Internal/Dev   : 3 sites (e.g. tests/util.test.js, scripts/migrate.js, ...)
```

If a single import site straddles categories (e.g. a util re-exported from both a route handler and a client component), it inherits the highest-risk category present.

The user reads the surface and decides whether the bump is worth the risk — Claude does not say "this is reachable" or "this is unreachable".

### Cross-repo / org-wide ranking (opt-in)

Only run when the user explicitly requested org fan-out. Apply on top of Impact × Exposure × CVSS:

- **Group by `(repo, package)` first.** GitHub raises N alerts per `(repo, package)` pair when there are N CVEs against the same dep. Collapse them — one bump fixes the cluster.
- **Cluster bonus.** A `(repo, package)` pair with many alerts on a Public/API repo is the highest-ROI pick, even if individual CVSS scores are mid. Example: 30 axios alerts in a webhook service > 1 CVSS-9 alert in an internal CLI tool — single PR closes 30 alerts AND it's high-exposure.
- **Repo character is a hint, not a verdict.** Backend/webhook repos *tend* to have Public/API import sites for HTTP libs; frontend repos *tend* to have Client-Bundle import sites for XSS sanitizers. Confirm via Exposure Mapping rather than assuming.

Output a ranked table: rank, repo, package, exposure summary (Public/API / Client-Bundle / Internal/Dev counts), alerts-collapsed. Let user pick or accept default (rank 1).

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
2. **Get advisory**: `gh api repos/<org>/<repo>/dependabot/alerts/<n>` — extract `first_patched_version` and `vulnerable_version_range`. The list endpoint hides these. For clusters, fetch every alert in the cluster.
3. **Locate**: direct dep (in `package.json`) or transitive? Find dependents:
   ```bash
   node -e "const l=require('./package-lock.json'); for(const[k,v]of Object.entries(l.packages||{}))if(v.dependencies?.['<pkg>']||v.devDependencies?.['<pkg>'])console.log(k,v.version);"
   ```
4. **Exposure Mapping**: see "Exposure Mapping" section. Categorize every import site (Public/API · Client-Bundle · Internal/Dev) and produce a surface summary for the user.
5. **Pick version (defensive minimal-patched)**:
   - Single alert: `^X.Y.Z` of `first_patched_version`.
   - Cluster: `^X.Y.Z` where `X.Y.Z = max(first_patched_version)` across every CVE in the cluster — i.e. the *minimal* version that supersets every patch. Compute via:
     ```bash
     for n in <alert-numbers>; do
       gh api repos/<org>/<repo>/dependabot/alerts/$n \
         --jq '.security_advisory.vulnerabilities[0].first_patched_version.identifier'
     done | sort -V | tail -1
     ```
   - **Do NOT default to "latest in same major."** Latest maximizes change surface and risks breaking transitives. Only override the defensive minimum when (a) the user explicitly asks, or (b) the minimum is unmaintained / yanked / pulls in its own fresh CVEs.
   - Cap at the same major as currently installed unless the user approves a major bump.
6. **Changelog scrape** — fetch release notes between current and target version. Try the GitHub release API first; fall back to `CHANGELOG.md` from the package tarball:
   ```bash
   # 1. Find the upstream repo
   PKG_REPO=$(npm view <pkg> repository.url | sed -E 's|.*github\.com[/:]([^.]+)\.git|\1|')
   # 2. Pull release notes for the target tag (try with and without leading "v")
   gh release view "v<target>" --repo "$PKG_REPO" --json tagName,body,createdAt 2>/dev/null \
     || gh release view "<target>" --repo "$PKG_REPO" --json tagName,body,createdAt
   # 3. Fallback: CHANGELOG from the published tarball
   npm pack <pkg>@<target> >/dev/null
   tar -xf <pkg>-<target>.tgz -C /tmp/<pkg>
   grep -inE 'BREAKING|DEPRECATED|MIGRATION|removed|drop(ped)? support' /tmp/<pkg>/package/CHANGELOG.md | head -50
   ```
   Surface the flagged lines verbatim to the user — do not paraphrase. If `BREAKING` / `DEPRECATED` / `MIGRATION` appears, raise the safety interlock to "second confirmation required" before proceeding.
7. **Safety interlock — PAUSE.** Print to the user:
   - chosen target version + reason (defensive minimal vs latest, why)
   - exposure surface (counts per category, sample paths)
   - changelog flags (verbatim lines, or "no flags" if clean)

   Wait for explicit go-ahead. If changelog flags were raised, require an unambiguous "yes, continue" / "I've handled it" — silence or ambiguous reply means stop.

8. After user OK: edit `package.json`, regen both lockfiles, run Parity Check, commit, ask before push.

## Override pattern (Node.js)

Use overrides for:
- **Transitive vulns** — package not in `dependencies`/`devDependencies`. Override is the only fix without bumping a parent.
- **Direct deps where transitives ALSO request the package** — bumping `dependencies.<pkg>` doesn't guarantee transitives get the same version (different semver ranges may hoist separately). Add the override anyway as defense-in-depth.

### Dual-write is MANDATORY

Many repos in this org run **npm in CI/CD** (the build that ships to prod) but **pnpm locally** (developer sanity checks). The two managers honor *different* override fields:

- npm reads top-level `"overrides": { ... }`
- pnpm reads `"pnpm": { "overrides": { ... } }`

Writing to only one of them produces **environment drift**: developers see one resolved version locally, CI ships another. This is exactly the bug class this skill exists to prevent. Dual-write both fields with the same target range, every time, even if only one lockfile is currently committed:

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

Then regenerate **both** lockfiles, in order:

```bash
pnpm install --no-frozen-lockfile
npm install --package-lock-only
```

The Parity Check at the end of the workflow asserts both produced the same resolved version — see "Verify (Parity Check)".

## Frontend repos (browser bundles + SSR)

Core workflow ports directly to React, Next.js, Vite, Vue, Svelte, Angular repos. Frontend specifics:

### Lockfile + override syntax per package manager

| Package manager | Lockfile | Override field in `package.json` | Regen command |
|---|---|---|---|
| npm | `package-lock.json` | `"overrides": { ... }` | `npm install --package-lock-only` |
| pnpm | `pnpm-lock.yaml` | `"pnpm": { "overrides": { ... } }` | `pnpm install --no-frozen-lockfile` |
| yarn (v1) | `yarn.lock` | `"resolutions": { ... }` | `yarn install` |
| yarn (berry, v2+) | `yarn.lock` | `"resolutions": { ... }` | `yarn install` |
| bun | `bun.lockb` (or `bun.lock`) | `"overrides": { ... }` | `bun install` |

If multiple lockfiles coexist (common during migrations or in npm-CI / pnpm-local setups), dual-write the override AND regen each. Parity Check still applies. Detect which lockfile the alert references via `.dependency.manifest_path` on the alert payload.

### Exposure Mapping for CSR + SSR mix

Modern frontend repos are rarely pure-CSR. Next.js, Nuxt, Remix, SvelteKit, even some Vite setups ship a server runtime alongside the bundle. The same dep can sit in **multiple Exposure categories simultaneously**.

Three categories at play in a frontend repo:

1. **Public/API** — server runtime that handles external HTTP/RPC traffic. Examples: Next.js `app/**/route.{ts,js}`, `pages/api/**`, `middleware.{ts,js}`, Remix `loader`/`action`, Nuxt server routes, SvelteKit `+page.server.{ts,js}` and `+server.{ts,js}`. Treat exactly like a backend Public/API import.
2. **Client-Bundle** — code that gets included in the browser bundle. Examples: `src/components/**`, `src/app/**/{page,layout,loading,error}.{ts,tsx}` without `.server.` suffix, `src/pages/**` (Next.js classic default exports), Vue/Svelte component files, anything imported by a `<script>`-shipped entry.
3. **Internal/Dev** — config, build, scripts, tests. Examples: `vite.config.*`, `next.config.*`, `*.config.{js,ts,mjs}`, `scripts/`, `tests/`, `**/*.test.*`, `**/*.spec.*`.

A single dep imported in BOTH `src/components/Foo.tsx` (Client-Bundle) AND `src/app/api/foo/route.ts` (Public/API) inherits the Public/API category for prioritization — surface BOTH to the user so they understand the blast radius isn't single-plane.

When the path is ambiguous (e.g. shared util `lib/http.ts` re-exported into both planes), ask the user; do not guess.

### Frontend-specific impact weighting

The Impact axis still leads, but the weighting context changes when the import site is purely Client-Bundle vs purely Public/API:

- **Client-Bundle import only** — high priority: XSS sanitizer bypass (dompurify, sanitize-html), prototype pollution in client state libs (lodash.merge, immer pre-9), template-injection in i18n libs, ReDoS in router/path matchers. Low priority: SSRF, header injection, NO_PROXY bypasses (no outbound HTTP from browser).
- **Public/API import (any plane that runs server-side)** — full server priority: SSRF, header injection, proto-pollution in HTTP clients all matter again.

A CVSS-9 SSRF in axios that only appears in Client-Bundle import sites is usually low priority; the same vuln in a Public/API import site is critical. The Exposure Mapping output is what tells you which case you're in.

### Framework version locks — proceed carefully

React/Next/Angular/Vue often pin transitive versions via peer deps or first-party meta-packages. Before bumping:
- Check `peerDependencies` on the parent framework (`next`, `react`, `@angular/core`).
- Major bumps of `@types/react`, `react-dom`, `next` mid-project frequently cascade through 30+ packages — flag as "needs separate PR + manual smoke test", do NOT roll into a security-bump PR.
- Bumps to `core-js`, `regenerator-runtime`, `tslib` are usually safe; bumps to anything ending in `-loader` or `-plugin` (webpack/rollup/vite ecosystem) often break the build — verify by running `pnpm build` (or equivalent) before opening the PR. The Changelog Scrape step will surface most of these via `BREAKING`/`removed` flags.

## Version range rules

- **Default to defensive minimal patched.** Use `^X.Y.Z` where `X.Y.Z` is the *minimal* version that supersets every applicable CVE patch (single alert: `first_patched_version`; cluster: `max(first_patched_version)` across the cluster). Latest-in-major is opt-in only — its larger change surface raises the chance the bump itself breaks something.
- Use `^X.Y.Z`, not `>=X.Y.Z`. Same lower bound but caps at `<next_major`, preventing surprise major bumps.
- Never `>X.Y.Z` — excludes the patched version itself, forces `X.Y.Z+1`, no benefit.
- For pnpm conditional overrides (vuln only in some range), use `<pkg>@<range>: <fix>` syntax, e.g. `"axios@<1.12.0": ">=1.12.0"`.
- **Conditional overrides rot.** If a prior conditional override exists (e.g. `"axios@<1.12.0": ">=1.12.0"`) and a new CVE range exceeds the prior cap, REPLACE the entry with a blanket `"axios": "^<minimal-patched>"`. Don't chain conditionals. Each new CVE batch tightens the floor.
- If the defensive minimum is unmaintained, yanked, or itself triggers fresh CVEs, escalate to the user — present the next-newest candidate plus its changelog scrape and let the user pick.

## Verify (Parity Check)

Two checks. Both must pass before the PR is opened.

### 1. Patched-version resolution

Confirm both lockfiles resolved the target package to a version `>= minimal_patched_version`:

```bash
# npm: read package-lock.json directly
NPM_VER=$(node -e "const l=require('./package-lock.json'); console.log(l.packages['node_modules/<pkg>']?.version || '');")

# pnpm: ask pnpm itself for the resolved root version (most reliable — robust to lockfile format changes)
PNPM_VER=$(pnpm why <pkg> --depth=0 --json 2>/dev/null \
  | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);const v=j[0]?.dependencies?.["<pkg>"]?.version || j[0]?.devDependencies?.["<pkg>"]?.version;console.log(v||"")})')

echo "npm=$NPM_VER pnpm=$PNPM_VER"
```

Both must show the patched version (or higher).

### 2. Lockfile parity (MANDATORY — abort PR on mismatch)

```bash
if [ -z "$NPM_VER" ] || [ -z "$PNPM_VER" ]; then
  echo "PARITY ABORT: could not resolve <pkg> in one of the lockfiles"
  exit 1
fi
if [ "$NPM_VER" != "$PNPM_VER" ]; then
  echo "PARITY ABORT: npm=$NPM_VER pnpm=$PNPM_VER"
  exit 1
fi
echo "PARITY OK: both resolved <pkg>@$NPM_VER"
```

If npm and pnpm resolve to different versions of the target package, **abort the PR**. Do NOT push, do NOT open the PR, do NOT commit a half-fixed state. Surface the mismatch to the user, with both versions and the likely cause:

- Override missing from one of the two override mechanisms (most common) — re-edit `package.json`, dual-write both fields, regen, recheck.
- Conditional pnpm override (`pkg@<range>`) that npm doesn't honor — replace with blanket override.
- pnpm hoisting boundary creating a transitive copy at a different version — may need `pnpm-lock.yaml`-level inspection (`pnpm why <pkg>` shows multiple versions).
- Different transitive resolution due to peer-dep mismatch — investigate before forcing.

Environment drift between dev (pnpm sanity check) and CI/CD (npm) is exactly the bug class this skill exists to prevent. The Parity Check is non-negotiable.

### Don't trust install stdout

`npm install --package-lock-only` may print `up to date` even when the override forced re-resolution and the lockfile actually changed. Same for pnpm in some edge cases. ALWAYS run the verify commands above — they read the lockfile directly.

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
