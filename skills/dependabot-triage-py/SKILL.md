---
name: dependabot-triage-py
description: '[scaffold — Python-specific blocks pending] Triage and fix Dependabot vulnerability alerts in Python repos (pip, poetry, uv, pdm, pipenv). v2.1 workflow with Standard (defensive) and Fast-Track (low-risk) modes — defensive minimal-patched versioning (PEP 440 ranges), exposure mapping (Public/API · Internal/Dev), CI workflow inspection, mandatory lockfile parity check across every PM that touches pyproject.toml / requirements*.txt, changelog scrape with BREAKING/DEPRECATED/MIGRATION flagging, and safety interlock before applying bumps. Fast-Track mode skips changelog + detailed exposure for Internal/Dev or CVSS<7 alerts, but parity check + dual-write are non-negotiable. Use when the user shares a Dependabot URL for a Python repo, asks to fix CVEs in a Python project, or asks which Python vulnerability to pick first.'
---

# Dependabot Triage & Fix — Python (v2.1)

> **Scaffold — not yet feature-complete.** Shared workflow is wired in; Python-specific blocks are marked `<!-- TODO(py): ... -->` and will be fleshed out in a follow-up. Some shared examples reference JS packages (axios, dompurify) — those are illustrative; the concepts apply to Python ecosystems.

## v2.1 highlights

- **Two modes — Standard and Fast-Track.** Standard is the defensive workflow (full exposure mapping, changelog scrape, safety interlock). Fast-Track is for low-risk bumps (Internal/Dev category, CVSS < 7, or user opt-in) — skips changelog + detailed exposure enumeration, single-confirmation interlock. Parity check + dual-write are non-negotiable in BOTH modes.
- **CI workflow inspection — first-class detection step.** Lockfile alone doesn't tell you what runs in CI. CI may use a different PM than the committed lockfile (e.g. yarn.lock committed, CI runs `npm install`), or may run `<pm> install` instead of lockfile-strict `<pm> ci`. Detection drives the override + parity matrix.
- **Defensive versioning** — pick the *minimal* patched version that fixes all in-cluster CVEs, not "latest in same major".
- **Exposure Mapping** replaces heuristic reachability — categorize every import site (Public/API · Client-Bundle · Internal/Dev) and present surface area to the user instead of trying to prove unreachability.
- **Mandatory lockfile parity check** — every PM that touches the manifest must resolve to the *same* version of the target package; mismatch aborts the PR. Required because CI/CD often runs a different PM than local sanity checks.
- **Changelog scrape with safety interlock** (Standard mode) — fetch release notes / CHANGELOG between current and target, flag `BREAKING` / `DEPRECATED` / `MIGRATION` keywords, pause for explicit user confirmation before applying the bump.
- **Auto-reversion** — if Fast-Track fails parity or the build fails post-bump, the skill offers to switch back to Standard mode for deeper analysis instead of grinding on retries.
- **Org-level fan-out is opt-in only** — never auto-trigger; org enumeration burns API rate limit and surfaces non-JS noise.

> **In scope for this skill**: pip, poetry, uv, pdm, pipenv.

## Scope

**Only Python repos** — pip, poetry, uv, pdm, pipenv ecosystems. Covers backend services (Django, Flask, FastAPI, Starlette, AIOHTTP), Lambda handlers, Celery workers, CLI tools, libraries, and notebook/script projects.

**NOT covered**: JavaScript/TypeScript (use the `dependabot-triage` skill), Go modules, Java (Maven / Gradle), Ruby (bundler), Rust (cargo), .NET (NuGet). If the user shares a Dependabot URL pointing to a non-Python repo (check `.dependency.package.ecosystem`), say so explicitly and stop — don't apply this skill's mechanics to those ecosystems.

The org-level fan-out *will* surface non-Python alerts (npm `axios`, Java packages). Filter those out of the ranked table or call them out as "out of scope for this skill — handle separately".

## How to install (one-time, per engineer)

```bash
npx skills add akshayrao14/dependabot-triage-py
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
- Local clone of the target repo (agent needs to read `pyproject.toml` / `requirements*.txt` / `Pipfile` + lockfiles).
- `python`, plus every PM the repo uses for lockfile regen (`pip`, `poetry`, `uv`, `pdm`, `pipenv` as applicable).
- Write permission to push a branch and open a PR (or accept that the agent stops at the commit step).

## What Claude will do (v2.1 workflow)

```
Detect PMs   →   Fetch + Rank   →   Mode Selection   →   { Standard | Fast-Track }   →   Apply + Parity Check   →   PR
```

The early steps (1–4) are the same in both modes. The middle steps branch by mode. The closing steps (regen + parity + PR) are identical and non-negotiable.

1. **Detect package managers in play** —
   <!-- TODO(py): full PM detection block.
        Committed manifests/lockfiles:
          - requirements*.txt / requirements*.in (pip / pip-tools)
          - Pipfile + Pipfile.lock (pipenv)
          - pyproject.toml [tool.poetry] + poetry.lock
          - pyproject.toml [tool.pdm] + pdm.lock
          - pyproject.toml [project] + uv.lock (uv)
          - constraints.txt (pip constraints — referenced via `-c`)
        CI / container install grep:
          - pip install -r ... / pip install --constraint ...
          - poetry install / poetry lock
          - uv sync / uv pip compile / uv pip install
          - pdm install / pdm sync
          - pipenv install / pipenv sync
          - pip-compile
        Mirror the JS step-1 "compare committed vs CI" logic.
        Flag hash-pinned requirements (pip-tools `--generate-hashes`) — bump
        breaks `pip install --require-hashes` unless hashes are regenerated. -->
2. **Fetch alerts**:
   <!-- TODO(py): mirror JS step 2 — filter `.dependency.package.ecosystem == "pip"`.
        Mixed-ecosystem repos: surface non-pip alerts as out-of-scope.
        Dependabot's pip ecosystem sometimes flags packages installed via apt/system
        Docker base images, not pip — verify the package is actually in pip's
        resolved tree (lockfile or `pip list`) before applying. -->
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
10. **Edit the manifest(s)** —
    <!-- TODO(py): per-PM edit instructions.
         - poetry: pin in [tool.poetry.dependencies] or [tool.poetry.group.*.dependencies]
         - uv: [tool.uv] override-dependencies = ["pkg>=X.Y.Z"]
         - pdm: [tool.pdm.resolution] overrides = { "pkg" = ">=X.Y.Z" }
         - pip (raw) / pipenv: NO transitive override mechanism — must bump the
           parent dep or use constraints.txt for pip.
         Required in BOTH modes. Preserve environment markers and extras. -->
11. **Regenerate every relevant lockfile** —
    <!-- TODO(py): per-PM regen commands.
         - poetry: poetry lock --no-update
         - uv: uv lock
         - pdm: pdm lock
         - pipenv: pipenv lock
         - pip-tools: pip-compile (with --generate-hashes if hash-pinned)
         For PMs without a committed lockfile, generate temp + delete before commit. -->
12. **Parity check** — for each PM detected in step 1, read its lockfile and assert every PM resolved to the *same* version of the target package. **Mismatch → abort PR in BOTH modes.**
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

## Prioritization framework

Three axes, in order:
1. **Impact** — RCE > data exfil/SSRF > DoS > logic bugs
2. **Exposure** — see Exposure Mapping below. NOT a heuristic guess about whether the vuln is reachable. A categorization of where the package is imported, presented to the user as a surface-area summary.
3. **CVSS** — tiebreaker only. Raw score without exposure context misleads (e.g. SSRF in axios shows 4.8 but matters more if axios is in Public/API).

## Exposure Mapping

Replaces the prior heuristic "reachability" model. Goal: stop trying to PROVE a vuln is unreachable — false negatives are dangerous. Instead, enumerate every import site of the target package and bucket each one. The user makes the final risk call from the surface area.

### Categories

<!-- TODO(py): two-category table (Client-Bundle dropped — Python rarely ships to browser).
     - **Public/API**: Django views.py / urls.py / middleware.py / consumers.py (ASGI),
       Flask/FastAPI/Starlette route decorators, AIOHTTP handlers, gRPC servicers,
       Lambda entry handlers, Celery tasks consuming external input,
       WSGI/ASGI entrypoints (wsgi.py, asgi.py).
     - **Internal/Dev**: setup.py, setup.cfg, pyproject.toml [build-system], conftest.py,
       tests/, scripts/, tox.ini, noxfile.py, Makefile-driven scripts, Sphinx config.
     Note: Streamlit / Gradio / Dash apps ship Python server-side — treat as Public/API. -->

### How to enumerate import sites

<!-- TODO(py): enumeration commands.
     Key gotcha: PyPI distribution name != Python import name often.
     Examples: PyYAML/yaml, Pillow/PIL, opencv-python/cv2, scikit-learn/sklearn,
     beautifulsoup4/bs4, python-dateutil/dateutil.

     Resolve dist→import via:
       python -c "from importlib.metadata import packages_distributions; \
         print({m: d for m, d in packages_distributions().items() if '<dist>' in d})"
     (Requires Python 3.10+; use `importlib_metadata` backport for 3.8/3.9.)

     Then grep with the import name:
       rg -t py "^(import |from ) *<import-name>([. ]|$)" -l | sort -u -->

### How to present to the user

<!-- TODO(py): adapt JS surface-summary format; drop Client-Bundle row.
     Example output:
       Exposure surface for requests in webhook-api:
         Public/API     : 8 sites (e.g. app/routes/webhook.py, services/external.py, ...)
         Internal/Dev   : 2 sites (e.g. tests/conftest.py, scripts/seed.py, ...) -->

### Cross-repo / org-wide ranking (opt-in)

Only run when the user explicitly requested org fan-out. Apply on top of Impact × Exposure × CVSS:

- **Group by `(repo, package)` first.** GitHub raises N alerts per `(repo, package)` pair when there are N CVEs against the same dep. Collapse them — one bump fixes the cluster.
- **Cluster bonus.** A `(repo, package)` pair with many alerts on a Public/API repo is the highest-ROI pick, even if individual CVSS scores are mid. Example: 30 HTTP-client alerts in a webhook service > 1 CVSS-9 alert in an internal CLI tool — single PR closes 30 alerts AND it's high-exposure.
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

When the same vulnerable package appears in more than one manifest (e.g. a root manifest AND a subpackage manifest), the default is **one PR per package touching all manifests** — one branch edits every affected manifest and regenerates every affected lockfile. This minimises the number of PRs and keeps the fix atomic.

Only split into per-manifest PRs when exposure categories differ significantly across manifests (e.g. `Public/API` in the root manifest, `Internal/Dev` in the sub-manifest) and the user explicitly wants separate review gates for each exposure level.

### Multi-PR sessions: sequential rebase conflict pattern

When the user chooses strategy (a) — one PR per package — and multiple PRs target the same manifest, **every subsequent PR will conflict on the manifest** at the same insertion point (the overrides block). This is predictable and not an error. The resolution is always additive: keep the HEAD overrides and append the incoming PR's key.

After each PR merges:
1. `git fetch origin <base>`
2. `git checkout <next-branch> && git rebase origin/<base>`
3. Resolve the conflict by keeping all existing override keys and adding the new one.
4. Regen the lockfile via the PM's lockfile-only install command (see the Override pattern section in this skill).
5. `git add <manifest> <lockfile> && git rebase --continue`
6. `git push --force-with-lease origin <next-branch>`

Do NOT use `--force` (without lease) — it skips the safety check that aborts if the remote has moved beyond what you fetched.

## Workflow per alert

Assumes "Detect package managers in play" (workflow step 1) is already done — the override + parity matrix below depends on knowing which PMs touch this repo.

<!-- TODO(py): workflow-per-alert numbered steps 1–8.
     1. Dedupe: GitHub raises one alert per committed lockfile.
     2. Get advisory: same `gh api repos/.../dependabot/alerts/<n>` — extract
        first_patched_version, vulnerable_version_range, cvss.score.
        Note: some Python alerts have GHSA only, no CVE — accept GHSA-prefix.
     3. Locate: parse poetry.lock / uv.lock TOML, pdm.lock, Pipfile.lock JSON,
        or requirements.txt.
     4. Exposure Mapping: see Categories above.
     5. Pick version (defensive minimal-patched, PEP 440):
        - Single alert: >=X.Y.Z,<(X+1).0.0 of first_patched_version
        - Cluster: same shape, X.Y.Z = max(first_patched_version) across cluster
        - Verify NOT yanked via PyPI .releases[<ver>][0].yanked
        - Check requires_python on PyPI doesn't exceed project's python_requires
        - Verify wheel availability for every deploy-target platform/Python combo
     6. Changelog scrape: PyPI project_urls.Changelog / Release notes URL via
        `curl -s https://pypi.org/pypi/<pkg>/json | jq -r '.info.project_urls'`,
        fall back to GitHub release notes (`gh release view`).
     7. Safety interlock — PAUSE (identical to JS).
     8. After user OK: edit manifest(s), regen lockfile(s), run Parity Check,
        commit, ask before push. -->

## Override pattern (Python)

<!-- TODO(py): per-PM override mechanisms.
     Dual-write semantics: write the override into EVERY PM that touches the project.

     | PM | Override field | Regen command |
     |---|---|---|
     | pip (raw) | NO TRANSITIVE OVERRIDE — pin in requirements.txt or use constraints.txt | `pip install -r requirements.txt -c constraints.txt` |
     | pip-tools | `*.in` source + compiled `*.txt` (with --generate-hashes if used) | `pip-compile requirements.in` |
     | poetry | `[tool.poetry.dependencies]` direct pin; transitive needs explicit `poetry add` | `poetry lock --no-update` |
     | uv | `[tool.uv] override-dependencies = ["pkg>=X.Y.Z"]` | `uv lock` |
     | pdm | `[tool.pdm.resolution] overrides = { "pkg" = ">=X.Y.Z" }` | `pdm lock` |
     | pipenv | Edit Pipfile [packages]; NO transitive override mechanism | `pipenv lock` |

     CRITICAL: raw pip and pipenv have NO transitive-override mechanism. If a
     transitive bump is required and only pip/pipenv are in play, the only fix is
     to bump the parent dep or migrate to uv/pdm. Hard-ineligible for Fast-Track.

     Preserve environment markers (e.g. `; python_version >= '3.10'`) and extras
     (e.g. `cryptography[ssh]>=42.0.0`) when overriding. -->

## Version range rules

<!-- TODO(py): PEP 440 semantics — NOT semver.
     - Default to defensive minimal patched. Use `>=X.Y.Z,<(X+1).0.0` where
       X.Y.Z is the *minimal* version that supersets every applicable CVE patch.
       (Universal — works in poetry, uv, pdm, pipenv, pip.)
     - Poetry-only alias: `^X.Y.Z` (caret) — same as `>=X.Y.Z,<(X+1).0.0`.
       Don't use in non-poetry contexts; not PEP 440 standard.
     - Never use bare `>=X.Y.Z` without an upper bound (anti-major-bump).
     - PEP 440 `~=X.Y.Z` (compatible release) is FINER than caret: `~=X.Y.Z`
       means `>=X.Y.Z,<X.(Y+1).0`. Use only when minor-only flexibility wanted.
     - For uv `override-dependencies` and pdm `overrides`, use full PEP 440
       specifier (e.g. `pkg>=X.Y.Z,<(X+1).0.0`).
     - Exact pin `==X.Y.Z` is common in `requirements.txt` for reproducibility;
       surface trade-off (no patch-level updates) to user before defaulting to exact pin.
     - Pre-release versions (1.0.0a1, .rc1, .dev1) are excluded by pip default unless
       `--pre` flag or exact `==` pin. If the only patched version is pre-release,
       flag explicitly. -->

## Verify (Parity Check)

<!-- TODO(py): per-PM patched-version resolution + parity assertion.
     For each detected PM, read the lockfile (or query the PM directly) and
     assert it resolves the target package to >= minimal_patched_version.

     ```bash
     # poetry: parse poetry.lock (TOML) for the resolved version
     POETRY_VER=$(python -c "import tomllib; \
       d=tomllib.load(open('poetry.lock','rb')); \
       print(next((p['version'] for p in d['package'] if p['name']=='<pkg>'), ''))")

     # uv: parse uv.lock (TOML)
     UV_VER=$(python -c "import tomllib; \
       d=tomllib.load(open('uv.lock','rb')); \
       print(next((p['version'] for p in d.get('package',[]) if p['name']=='<pkg>'), ''))")

     # pdm: pdm list --json + filter, OR parse pdm.lock TOML
     PDM_VER=$(pdm list --json 2>/dev/null | jq -r '.[] | select(.name=="<pkg>") | .version')

     # pipenv: parse Pipfile.lock (JSON)
     PIPENV_VER=$(jq -r '.default["<pkg>"].version // .develop["<pkg>"].version' Pipfile.lock | sed 's/^==//')

     # pip (raw) / pip-tools: read requirements.txt directly, or check venv
     PIP_VER=$(grep -E '^<pkg>==' requirements.txt | sed 's/^<pkg>==//' | head -1)
     ```

     Then collect non-empty versions, sort -u, abort PR if count > 1.

     Special case for raw pip/pip-tools: a `requirements.txt` with `<pkg>>=X.Y.Z`
     (not pinned exactly) is NOT a lockfile — re-resolves on every `pip install`.
     Parity check needs version-pinning verification, not just file presence.

     Hash-pinned requirements (`--require-hashes`): after the bump, regenerate hashes
     via `pip-compile --generate-hashes`. Forgetting breaks CI silently in dev,
     loudly in prod. -->

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

<!-- TODO(py): Python-specific platform notes.
     - **Native-wheel risk**: bumps of compiled packages (cryptography, lxml, numpy,
       pandas, pillow, psycopg2, cffi, bcrypt, pyodbc, pyarrow) need platform-specific
       wheel re-resolve. Check PyPI .releases[<ver>] filename list for manylinux /
       musllinux / macosx / win_amd64 wheels matching every deploy target before
       pinning. Patched version may drop a platform wheel → silent CI break.
     - **Hash mismatches**: when dev and CI use different index URLs (private PyPI mirror,
       devpi), hash-pinned requirements can fail with "hash mismatch" — same file,
       different mirror's hash. Surface this if hash check fails.
     - **requires_python skew**: bumping to a version with a higher Python floor than
       the project supports breaks install on older Python deploys. -->
