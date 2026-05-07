# dependabot-triage (v2.1)

[![skills.sh](https://skills.sh/b/akshayrao14/git-practices)](https://skills.sh/akshayrao14/git-practices)

Agent Skill for triaging and fixing Dependabot vulnerability alerts in JavaScript / TypeScript repos (Node.js services AND browser frontends). Covers npm, pnpm, yarn, bun lockfiles. Compatible with any agent that supports the [Agent Skills standard](https://github.com/anthropics/skills) — Claude Code, Codex CLI, Gemini CLI, Cursor, etc.

## Install

```bash
npx skills add akshayrao14/git-practices
```

Or clone manually into your agent's skills dir (`~/.codex/skills/`, `~/.claude/skills/`, or `~/.agents/skills/`).

## What it does

Given a Dependabot alert (URL, alert number, or just the package name), Claude will:

1. Fetch the alert + advisory via `gh api`.
2. Rank open alerts using a three-axis framework (Impact × Exposure × CVSS).
3. **Map exposure** — enumerate every import site of the target package and bucket each into Public/API · Client-Bundle · Internal/Dev.
4. **Pick a defensive minimal-patched version** — the smallest version that supersets every CVE patch in the cluster (not "latest in same major").
5. **Scrape the changelog** between current and target version, flagging `BREAKING` / `DEPRECATED` / `MIGRATION` keywords.
6. **PAUSE for explicit user OK** before applying the bump — required, with a second confirmation if changelog flags were raised.
7. Dual-write the override into both `pnpm.overrides` and the top-level `overrides` field in `package.json`. Regenerate both lockfiles.
8. **Run a parity check.** If npm and pnpm resolve to different versions of the target package, abort and surface the mismatch — do not open the PR.
9. Open a PR off the latest remote base branch — one PR per package by default.

Full behavior spec is in [`SKILL.md`](./SKILL.md).

## v2.1 changes

This version replaces the earlier "guess if it's reachable" workflow with a more defensive, high-integrity pipeline, and adds an opt-in Fast-Track mode for low-risk bumps:

- **Two modes — Standard and Fast-Track.** Standard is the full defensive workflow; Fast-Track is a velocity-optimized shortcut for dev-dependency or low-CVSS bumps. Lockfile integrity is non-negotiable in both modes.
- **Exposure Mapping** replaces heuristic reachability. Stop trying to prove a vuln is unreachable; categorize import sites and let the user make the risk call from the surface area.
- **Defensive minimal-patched versioning** — smaller change surface, lower chance the bump itself breaks something. Latest-in-major is now opt-in.
- **Mandatory lockfile parity check** between `package-lock.json` and `pnpm-lock.yaml`. Required because CI/CD runs npm but local sanity checks run pnpm — drift between the two is the exact class of bug this skill exists to prevent.
- **Changelog scrape with safety interlock** (Standard mode). No bump is applied without surfacing breaking-change flags first and getting explicit user confirmation.
- **Auto-reversion** — if Fast-Track hits a parity failure or a build/test/hook failure, the skill offers to re-run the same package in Standard mode for deeper analysis instead of retrying blindly.
- **Org-level fan-out is opt-in only.** Even if the user pastes an org URL, the skill confirms before paginating across the entire org (avoids API rate-limit burn and non-JS noise).

## Fast-Track mode

For low-risk bumps where the full Standard pipeline (exposure enumeration + changelog scrape + double-confirmation interlock) is overkill.

### When Fast-Track is offered

Any one of:

- The dominant Exposure category is **Internal/Dev** (configs, scripts, tests, tooling) with no `Public/API` import sites.
- **CVSS < 7.0** AND no `Public/API` import sites.
- The user explicitly asks: `"fast-track"`, `"just bump it"`, `"skip the changelog"`.

If none apply, the skill defaults to Standard.

### When Fast-Track is refused

Even if the user asks for it, the skill falls back to Standard when:

- The package has any `Public/API` import sites AND CVSS ≥ 7.0.
- The advisory severity is `critical`.
- A cross-major bump would be required.

### Speed/risk trade-off

| Step | Standard | Fast-Track |
|---|---|---|
| Exposure Mapping (per-site enumeration) | Full listing | Single-line dominant category only |
| Changelog scrape | Yes (BREAKING / DEPRECATED / MIGRATION flagged) | **Skipped** |
| Safety interlock | Up to two confirmations | One confirmation |
| Defensive minimal-patched version | Yes | Yes |
| **Dual-write override** | **Yes** | **Yes** |
| **Both-lockfile regeneration** | **Yes** | **Yes** |
| **Parity check + abort on mismatch** | **Yes** | **Yes** |
| Commit + push gated on user OK | Yes | Yes |

The bottom block — dual-write, regeneration, parity check — is non-negotiable. We never sacrifice environment parity for speed; environment drift between dev (pnpm) and CI (npm) is the bug class this skill exists to prevent.

### Auto-reversion on failure

If a Fast-Track bump fails the parity check, breaks the build, or fails a pre-commit hook, the skill offers to switch the same package back to Standard mode rather than retry blindly. Repeated Fast-Track retries on a failing bump is exactly the trap the mode is designed to avoid.

## Exposure Mapping categories

Every import site of the target package is bucketed into one of:

| Category | Definition | Example file paths |
|---|---|---|
| **Public/API** | Code that serves HTTP/RPC/webhook traffic from outside the trust boundary. | `handlers/`, `routes/`, `controllers/`, `app/api/**/route.{ts,js}`, `pages/api/**`, `middleware.{ts,js}`, `+server.{ts,js}`, `+page.server.{ts,js}`, Lambda entry handlers, Express/Fastify routes |
| **Client-Bundle** | Code that ships in the browser bundle. | `src/components/**`, `src/app/**/{page,layout}.{ts,tsx}` (no `.server.`), `src/pages/**` (Next.js classic), Vue/Svelte components |
| **Internal/Dev** | Build, tooling, scripts, tests, configs — does not run in prod request path or ship to the browser. | `vite.config.*`, `next.config.*`, `*.config.{js,ts,mjs}`, `scripts/`, `tests/`, `**/*.test.*`, `**/*.spec.*`, `.husky/`, `.cicd/` |

The skill presents the surface to the user as counts + sample paths per category. If a single import site straddles categories, it inherits the highest-risk one. The user reads the surface and decides — Claude does not pronounce a vuln "unreachable."

## Parity Check

After regenerating both lockfiles, the skill reads each one independently and compares the resolved version of the target package:

```
npm  → 1.16.0
pnpm → 1.16.0
PARITY OK
```

vs

```
npm  → 1.16.0
pnpm → 1.12.2
PARITY ABORT
```

A mismatch aborts the PR. Common causes:

- The override was written to only one of the two override fields (`pnpm.overrides` vs top-level `overrides`).
- A conditional pnpm override (`pkg@<range>`) that npm doesn't honor.
- pnpm hoisting created a transitive copy at a different version (run `pnpm why <pkg>` to inspect).
- Peer-dep mismatch produced different transitive resolutions.

The skill does NOT push the PR until parity is restored. Local-vs-CI environment drift is the class of bug v2.1 exists to prevent.

## Install

Clone the repo anywhere, then run the install script:

```bash
git clone https://github.com/akshayrao14/git-practices.git   # anywhere on disk
bash git-practices/skills/dependabot-triage/install.sh
```

The script auto-detects your agent and symlinks this folder into the right skills dir:

| Agent | Target dir |
|-------|-----------|
| Codex CLI | `~/.codex/skills/dependabot-triage` |
| Claude Code | `~/.claude/skills/dependabot-triage` |
| Generic / open-standard | `~/.agents/skills/dependabot-triage` |

Restart your agent session afterward so the skill is picked up.

### Custom skills directory

Override the target with `SKILLS_HOME` (or legacy `CLAUDE_SKILLS_HOME`):

```bash
SKILLS_HOME=/path/to/skills bash git-practices/skills/dependabot-triage/install.sh
```

### Uninstall

```bash
rm ~/.codex/skills/dependabot-triage      # or ~/.claude/skills/... or ~/.agents/skills/...
```

## Prerequisites

- `gh` CLI authenticated against the target repo (`gh auth status`).
- Local clone of the repo whose alerts you're triaging.
- `node`, `pnpm`, and `npm` for lockfile regeneration AND the parity check.
- `ripgrep` (`rg`) recommended for the Exposure Mapping step; falls back to `grep` if unavailable.

## Trigger phrases

Any of these route Claude to this skill:

- "Triage Dependabot alerts in `<repo>`"
- "Which vuln should I fix first? <github.com/.../security/dependabot URL>"
- "Fix Dependabot alert #<N> in this repo"
- "Bump `<pkg>` to a non-vulnerable version"

Org-wide triage requires explicit phrasing — do NOT auto-fan-out:

- "Fan out across the org"
- "Triage all repos in `<org>`"
- "Run org-wide triage"

## Updating

The install is a symlink, so `git pull` in the cloned repo immediately propagates updates. No reinstall needed.
