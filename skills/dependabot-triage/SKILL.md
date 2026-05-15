---
name: dependabot-triage
description: Triage and fix Dependabot vulnerability alerts in JavaScript/TypeScript repos (Node.js services AND browser frontends). v2.1 workflow with Standard (defensive) and Fast-Track (low-risk) modes — defensive minimal-patched versioning, exposure mapping (Public/API · Client-Bundle · Internal/Dev), CI workflow inspection to detect every PM in play, mandatory lockfile parity check across every PM that touches package.json, changelog scrape with BREAKING/DEPRECATED/MIGRATION flagging, and safety interlock before applying bumps. Fast-Track mode skips changelog + detailed exposure for Internal/Dev or CVSS<7 alerts, but parity check + dual-write are non-negotiable. Covers npm, pnpm, yarn, bun lockfiles. Use when the user shares a Dependabot URL, asks to fix CVEs, or asks which vulnerability to pick first.
---

# Dependabot Triage & Fix (v2.1)

## v2.1 highlights

- **Two modes — Standard and Fast-Track.** Standard is the defensive workflow (full exposure mapping, changelog scrape, safety interlock). Fast-Track is for low-risk bumps (Internal/Dev category, CVSS < 7, or user opt-in) — skips changelog + detailed exposure enumeration, single-confirmation interlock. Parity check + dual-write are non-negotiable in BOTH modes.
- **CI workflow inspection — first-class detection step.** Lockfile alone doesn't tell you what runs in CI. CI may use a different PM than the committed lockfile (e.g. yarn.lock committed, CI runs `npm install`), or may run `<pm> install` instead of lockfile-strict `<pm> ci`. Detection drives the override + parity matrix.
- **Defensive versioning** — pick the *minimal* patched version that fixes all in-cluster CVEs, not "latest in same major".
- **Exposure Mapping** replaces heuristic reachability — categorize every import site (Public/API · Client-Bundle · Internal/Dev) and present surface area to the user instead of trying to prove unreachability.
- **Mandatory lockfile parity check** — every PM that touches `package.json` (npm, pnpm, yarn classic/berry, bun) must resolve to the *same* version of the target package; mismatch aborts the PR. Required because CI/CD often runs a different PM than local sanity checks (e.g. npm-CI + pnpm-local, or yarn-local + npm-CI).
- **Changelog scrape with safety interlock** (Standard mode) — fetch release notes / CHANGELOG between current and target, flag `BREAKING` / `DEPRECATED` / `MIGRATION` keywords, pause for explicit user confirmation before applying the bump.
- **Auto-reversion** — if Fast-Track fails parity or the build fails post-bump, the skill offers to switch back to Standard mode for deeper analysis instead of grinding on retries.
- **Org-level fan-out is opt-in only** — never auto-trigger; org enumeration burns API rate limit and surfaces non-JS noise.

## Scope

**Only JavaScript / TypeScript repos** — npm, pnpm, yarn, bun ecosystems. Covers backend Node.js services, frontend bundles (CSR), server-rendered apps (SSR), and mixed SSR+CSR frameworks (Next.js, Nuxt, Remix, SvelteKit).

**NOT yet covered**: Python (pip / poetry / uv), Go modules, Java (Maven / Gradle), Ruby (bundler), Rust (cargo), .NET (NuGet). If the user shares a Dependabot URL pointing to a repo whose alerts are non-JS (check `.dependency.package.ecosystem`), say so explicitly and stop — don't apply this skill's mechanics to those ecosystems.

The org-level fan-out *will* surface non-JS alerts (e.g. Python `pillow`, Java packages). Filter those out of the ranked table or call them out as "out of scope for this skill — handle separately".

## How to install (one-time, per engineer)

```bash
npx skills add akshayrao14/dependabot-triage
```

Installs into the right skills dir for your agent (Codex `~/.codex/skills`, Claude Code `~/.claude/skills`, or open-standard `~/.agents/skills`). Restart your agent session afterward — the skill should appear in `/skills` (Claude Code) or via the agent's skill discovery.

## How to invoke

Trigger phrases (any of these will route the agent to this skill):

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
- Local clone of the target repo (agent needs to read `package.json` + lockfiles).
- `node`, `pnpm`, and/or `npm` installed for lockfile regeneration.
- Write permission to push a branch and open a PR (or accept that the agent stops at the commit step).

## What Claude will do (v2.1 workflow)

```
Detect PMs   →   Fetch + Rank   →   Mode Selection   →   { Standard | Fast-Track }   →   Apply + Parity Check   →   PR
```

The early steps (1–4) are the same in both modes. The middle steps branch by mode. The closing steps (regen + parity + PR) are identical and non-negotiable.

1. **Detect package managers in play** — before fetching alerts, figure out which PM(s) actually touch this repo, in *every* context (local install, CI install, container build). The override + parity matrix below depends on this.
   - **Committed lockfiles**: `ls package-lock.json pnpm-lock.yaml yarn.lock bun.lock* 2>/dev/null`.
   - **CI / container install commands** — grep CI configs and Dockerfiles for the actual install command:
     ```bash
     rg -tg '*.yml' -tg '*.yaml' \
       '\b(npm (install|ci)|yarn install|pnpm install|bun install)\b' \
       .github .gitlab-ci.yml Dockerfile* docker-compose*.yml circle.yml .circleci 2>/dev/null
     ```
   - **Compare** committed lockfiles against CI install commands. If CI's PM differs from the committed-lockfile PM, OR no lockfile is committed for the CI PM, expand the override + parity matrix accordingly (see "Override pattern" and "Verify (Parity Check)").
   - **Don't ask the user up-front to classify the PM setup.** They often only know half the picture (their local context, not CI; or vice versa). Detect from lockfile + CI grep, show what was found, and ask only to confirm anomalies (e.g. *"I see yarn.lock committed but CI runs `npm install` — confirm both are intentional?"*).
2. **Fetch alerts**:
   - Repo URL → `gh api "repos/<org>/<repo>/dependabot/alerts?state=open&per_page=100"`
   - Org URL → only after explicit user confirmation, then `gh api "orgs/<org>/dependabot/alerts?state=open&per_page=100"` (paginates across every repo).
   - Filter `.dependency.package.ecosystem == "npm"` for this skill; surface non-JS alerts as out-of-scope.
   - Dedupe by `(repo, package)`.
   - **Mixed-ecosystem repos (Python + npm, Go + npm, etc.):** group alerts by ecosystem BEFORE presenting the ranked table. Output out-of-scope ecosystems as a separate blocked section at the top — e.g. "⛔ Out of scope for this skill (handle separately): pillow × 10 (pip), urllib3 × 2 (pip)." The user needs to see what's NOT being covered so they can act on it elsewhere. Never silently drop non-JS alerts.
3. **Rank** using the prioritization framework (Impact × Exposure × CVSS).
4. **Read advisory** for the top pick — extract `first_patched_version`, `vulnerable_version_range`, and `cvss.score`. For clusters, compute the *minimal* version that supersets every CVE patch.
5. **Mode selection — recommend Fast-Track or Standard.** See "Fast-Track mode" section for the eligibility rules. Present a one-liner recommendation alongside the ranked summary, e.g. *"This is a dev-dependency; would you like to Fast-Track this fix?"* Default to Standard if the user is silent or ambiguous. Also default to Standard when no lockfile is committed for the CI PM — every CI build re-resolves transitives fresh, the override field is the only pin, and the case is Fast-Track-ineligible (no lockfile parity to check).

### Standard mode (steps 6–8) — full defensive pipeline

6. **Exposure Mapping** — locate every import site of the target package in source, classify each into Public/API · Client-Bundle · Internal/Dev (see "Exposure Mapping" section). Output counts + sample paths.
7. **Changelog scrape** — fetch release notes / `CHANGELOG.md` between currently-installed and target version. Grep for `BREAKING`, `DEPRECATED`, `MIGRATION`, `removed`, `dropped support`. Surface flagged lines verbatim.
8. **Safety interlock — PAUSE.** Print the exposure summary + changelog flags + chosen target version to the user. Wait for explicit OK ("yes", "go", "looks fine", etc) before any file edits. If `BREAKING`/`DEPRECATED`/`MIGRATION` was flagged, require a second affirmative.

### Fast-Track mode (steps 6–8) — low-risk shortcut

6. **Lightweight exposure check** — run the import-site grep ONCE to confirm the dominant Exposure category, but do NOT enumerate paths. Output: `Exposure: Internal/Dev (8 sites)`. Stops here; no per-category breakdown, no path listing.
7. **Skip changelog scrape.** (Fast-Track explicitly trades changelog visibility for speed; the eligibility rules below cap the blast radius this can cause.)
8. **Single-confirmation interlock — PAUSE.** Print: target version + dominant Exposure category + CVSS + reason for Fast-Track eligibility. One affirmative ("yes", "go", "ship it") moves on; anything ambiguous falls back to Standard.

### Apply (steps 9–13) — identical in both modes, non-negotiable

9. **Confirm branching strategy AND base branch.** Detect default branch via `gh repo view --json defaultBranchRef`; never hardcode `main`. Default: one PR per package off latest `origin/<detected-base>`.
10. **Edit `package.json`** — write the override field for *every* PM detected in step 1 (npm `overrides`, pnpm `pnpm.overrides`, yarn `resolutions`, bun `overrides`; see "Override pattern"). Required in BOTH modes.
11. **Regenerate every relevant lockfile** — for each PM detected in step 1, run its install. For PMs without a committed lockfile, generate a temp one for the parity check and **delete it before commit** (see "Verify (Parity Check)"). No "primary" lockfile.
12. **Parity check** — for each PM detected in step 1, read its lockfile (or `<pm> why` output) and assert every PM resolved to the *same* version of the target package. **Mismatch → abort PR in BOTH modes.** See "Auto-reversion on parity / build failure" for what to do next.
13. **Commit on the branch and open a PR** — with explicit user OK before pushing.

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
- CI runs `<pm> install` (not `<pm> ci` / lockfile-strict) without a committed lockfile for that PM. Every CI build re-resolves transitives fresh — the override field is the only pin on that side. Higher stakes; deserves Standard's full visibility. Also parity-check-ineligible: there's no committed lockfile to compare against.

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
| Dual-write override (`pnpm.overrides` + top-level `overrides`) | Yes |
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

**In multi-PR sessions, run `git fetch origin <base>` immediately before each new branch creation** — do not reuse a fetch from earlier in the session. Prior PRs opened in the same session may have already been merged (auto-merge, quick review), meaning `origin/<base>` has advanced since the last fetch. A stale fetch produces the same conflict-on-merge problem that fresh-fetching was meant to prevent.

### Strategy options — ask the user

Before starting, ask which strategy they want for this batch:
- (a) **One PR per package** (default) — atomic, clean revert
- (b) **One PR for multiple packages** — fewer PRs to review, but coupled revert
- (c) **Stack onto an existing branch / open PR** — useful if the prior PR is still open and the user wants to bundle

If user says "whatever's cleaner", pick (a).

### Same package in multiple manifests

When the same vulnerable package appears in more than one manifest (e.g. root `package.json` AND `subpackage/package.json`), the default is **one PR per package touching all manifests** — one branch edits every affected `package.json` and regenerates every affected lockfile. This minimises the number of PRs and keeps the fix atomic.

Only split into per-manifest PRs when exposure categories differ significantly across manifests (e.g. `Public/API` in the root manifest, `Internal/Dev` in the sub-manifest) and the user explicitly wants separate review gates for each exposure level.

### Multi-PR sessions: sequential rebase conflict pattern

When the user chooses strategy (a) — one PR per package — and multiple PRs target the same manifest, **every subsequent PR will conflict on `package.json`** at the same insertion point (the overrides block). This is predictable and not an error. The resolution is always additive: keep the HEAD overrides and append the incoming PR's key.

After each PR merges:
1. `git fetch origin <base>`
2. `git checkout <next-branch> && git rebase origin/<base>`
3. Resolve the conflict by keeping all existing override keys and adding the new one.
4. Regen the lockfile: `npm install --package-lock-only` (or equivalent PM).
5. `git add package.json package-lock.json && git rebase --continue`
6. `git push --force-with-lease origin <next-branch>`

Do NOT use `--force` (without lease) — it skips the safety check that aborts if the remote has moved beyond what you fetched.

## Workflow per alert

Assumes "Detect package managers in play" (workflow step 1) is already done — the override + parity matrix below depends on knowing which PMs touch this repo.

1. **Dedupe**: GitHub raises one alert per committed lockfile. Two committed lockfiles (e.g. `package-lock.json` + `pnpm-lock.yaml`) = 2 alerts, 1 vuln. Fix the package once.
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

   **Transitive-dep qualifier:** Before demanding a second confirmation, check whether the flagged package has any direct import sites in source (from the Exposure Mapping step). If zero direct imports exist — the package is purely transitive — state this explicitly alongside the flag: *"This flag appears in a package that is not directly imported by your source code. The breaking change is unlikely to affect you unless your code parses its error messages or hooks into its internals."* This collapses two confirmation rounds into one when the flag is clearly irrelevant to the calling code.
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

Write the override field for **every PM detected in step 1**, in any context (local install, CI install, container build). Different PMs honor *different* override fields:

| PM | Override field in `package.json` |
|---|---|
| npm | `overrides` |
| pnpm | `pnpm.overrides` |
| yarn classic (v1) | `resolutions` |
| yarn berry (v2+) | `resolutions` |
| bun | `overrides` |

Writing to only one when more than one PM is in play produces **environment drift**: developers see one resolved version locally, CI ships another. This is exactly the bug class this skill exists to prevent. Write the override into every relevant field with the same target range, every time, even if only one lockfile is currently committed.

A common pattern in this org is npm-CI + pnpm-local; the same drift class applies to any PM mismatch (yarn-local + npm-CI, bun-local + npm-CI, etc.). The canonical npm + pnpm dual-write looks like:

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

For a yarn + npm pair, you'd write `resolutions` AND `overrides`; for yarn + pnpm, `resolutions` AND `pnpm.overrides`. Substitute per the table above.

Then regenerate every relevant lockfile. Canonical pnpm + npm pair:

```bash
pnpm install --no-frozen-lockfile
npm install --package-lock-only
```

For other PMs the regen commands live in the table at "Frontend repos → Lockfile + override syntax per package manager".

The Parity Check at the end of the workflow asserts every PM produced the same resolved version — see "Verify (Parity Check)".

### npm `EOVERRIDE`: override must fit inside the direct-dep range

npm errors out when `overrides.<pkg>` doesn't sit inside the range declared in `dependencies` / `devDependencies`:

> `EOVERRIDE: Override for <pkg>@<range> conflicts with direct dependency`

Two canonical fixes:

- **Tighten the direct dep range** to be consistent with (or narrower than) the override. Example: a direct `"postcss": "^8"` paired with `overrides.postcss: "^8.5.10"` errors; change the direct dep to `"postcss": "^8.5.10"` and the override applies cleanly.
- **Self-reference via `"$<pkg>"`** if the direct dep range shouldn't be touched: `"overrides": { "postcss": "$postcss" }` — npm reuses the resolved direct-dep version. Useful when the direct dep is already at a patched version and you only need to force transitives to follow.

Yarn `resolutions` does *not* have this constraint — npm `overrides` only.

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

Two checks. Both must pass before the PR is opened. Run for **every PM detected in step 1**, not just the canonical npm + pnpm pair.

### 1. Patched-version resolution

For each detected PM, confirm it resolves the target package to `>= minimal_patched_version`. Asking the PM directly (or reading the lockfile directly) is the most reliable method — robust to lockfile format changes:

```bash
# npm: read package-lock.json directly
NPM_VER=$(node -e "const l=require('./package-lock.json'); console.log(l.packages['node_modules/<pkg>']?.version || '');")

# pnpm: ask pnpm itself for the resolved root version
PNPM_VER=$(pnpm why <pkg> --depth=0 --json 2>/dev/null \
  | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);const v=j[0]?.dependencies?.["<pkg>"]?.version || j[0]?.devDependencies?.["<pkg>"]?.version;console.log(v||"")})')

# yarn classic (v1)
YARN_VER=$(yarn why <pkg> 2>/dev/null | grep -oE 'Found "<pkg>@[^"]+"' | head -1 | sed -E 's/.*@//; s/"$//')

# yarn berry (v2+)
YARN_VER=$(yarn why <pkg> --json 2>/dev/null | head -1 \
  | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);const k=Object.keys(j.children||{})[0];console.log(j.children?.[k]?.locator?.split("@npm:")[1]||"")}catch{}})')

# bun
BUN_VER=$(bun pm ls --all 2>/dev/null | grep -E '\b<pkg>@' | head -1 | sed -E 's/.*@//')

echo "npm=$NPM_VER pnpm=$PNPM_VER yarn=$YARN_VER bun=$BUN_VER"
```

Use only the variables for PMs actually in play; ignore the rest. All must show the patched version (or higher).

### Generating a temp lockfile (PMs without a committed lockfile)

When CI uses a PM that has no committed lockfile (e.g. yarn.lock committed, CI runs `npm install`), generate a temp lockfile *just for the parity check*, then **delete it before commit**:

| PM | Lockfile-only regen | Resulting file |
|---|---|---|
| npm | `npm install --package-lock-only` | `package-lock.json` |
| pnpm | `pnpm install --lockfile-only` | `pnpm-lock.yaml` |
| yarn classic | `yarn install --mode=update-lockfile` | `yarn.lock` |
| yarn berry | `yarn install --mode=update-lockfile` | `yarn.lock` |
| bun | `bun install --frozen-lockfile=false` | `bun.lock` |

> ⚠ Do **NOT** commit a generated lockfile from a PM that doesn't already have one committed. Dual-lockfile drift is the exact bug class this skill exists to prevent — a generated `yarn.lock` alongside an authoritative `pnpm-lock.yaml` will silently diverge on the next `yarn install` and you've doubled the surface area, not halved it.

When no lockfile is committed for a detected CI PM, also explicitly assert:

- The override field for that PM is present in `package.json` (see PM table in "Override pattern → Dual-write is MANDATORY").
- The direct-dep range for the target package is consistent with the override (anti-`EOVERRIDE`; see "npm `EOVERRIDE`").

### 2. Lockfile parity (MANDATORY — abort PR on mismatch)

```bash
# Collect non-empty resolved versions across all detected PMs
VERS=$(printf '%s\n' "$NPM_VER" "$PNPM_VER" "$YARN_VER" "$BUN_VER" | grep -v '^$' | sort -u)
COUNT=$(echo "$VERS" | grep -c .)

if [ "$COUNT" -eq 0 ]; then
  echo "PARITY ABORT: could not resolve <pkg> in any lockfile"
  exit 1
fi
if [ "$COUNT" -gt 1 ]; then
  echo "PARITY ABORT: PMs disagree:"
  echo "$VERS"
  exit 1
fi
echo "PARITY OK: all PMs resolved <pkg>@$VERS"
```

If any pair of PMs resolves to different versions of the target package, **abort the PR**. Do NOT push, do NOT open the PR, do NOT commit a half-fixed state. Surface the mismatch to the user, with all versions and the likely cause:

- Override missing from one of the override mechanisms (most common) — re-edit `package.json`, write the override into every relevant field, regen, recheck.
- Conditional pnpm override (`pkg@<range>`) that npm doesn't honor — replace with blanket override.
- pnpm hoisting boundary creating a transitive copy at a different version — may need `pnpm-lock.yaml`-level inspection (`pnpm why <pkg>` shows multiple versions).
- npm `EOVERRIDE` blocked the override silently or failed loudly — check the direct-dep range (see "npm `EOVERRIDE`").
- Different transitive resolution due to peer-dep mismatch — investigate before forcing.

Environment drift between dev and CI/CD (any PM pair: npm-CI + pnpm-local, npm-CI + yarn-local, bun-local + npm-CI, etc.) is the bug class this skill exists to prevent. The Parity Check is non-negotiable.

### Don't trust install stdout

`npm install --package-lock-only` may print `up to date` even when the override forced re-resolution and the lockfile actually changed. Same for pnpm, yarn, and bun in some edge cases. ALWAYS run the verify commands above — they read the lockfile (or PM's own resolution graph) directly.

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

## Platform notes

- **Windows + OneDrive**: `yarn install` / `npm install` / `pnpm install` can hit `EPERM` on `.node` native binaries because OneDrive briefly locks files mid-sync. Single retry usually clears it. Don't kill processes, don't escalate to `--force` — just retry once.
