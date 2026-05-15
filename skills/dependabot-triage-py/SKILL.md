---
name: dependabot-triage-py
description: Triage and fix Dependabot vulnerability alerts in Python repos (pip, poetry, uv, pdm, pipenv). v2.1 workflow with Standard (defensive) and Fast-Track (low-risk) modes — defensive minimal-patched versioning (PEP 440 ranges), exposure mapping (Public/API · Internal/Dev), CI workflow inspection to detect every PM in play, mandatory lockfile parity check across every PM that touches pyproject.toml / requirements*.txt, changelog scrape with BREAKING/DEPRECATED/MIGRATION flagging, and safety interlock before applying bumps. Fast-Track mode skips changelog + detailed exposure for Internal/Dev or CVSS<7 alerts, but parity check + dual-write are non-negotiable. Use when the user shares a Dependabot URL for a Python repo, asks to fix CVEs in a Python project, or asks which Python vulnerability to pick first.
---

# Dependabot Triage & Fix — Python (v2.1)

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

1. **Detect package managers in play** — before fetching alerts, figure out which PM(s) actually touch this repo, in *every* context (local install, CI install, container build). The override + parity matrix below depends on this.
   - **Committed manifests / lockfiles** — start at repo root, then walk subdirectories for monorepo / multi-Lambda / multi-service layouts:
     ```bash
     # Root + common manifest types
     ls requirements*.txt requirements*.in pyproject.toml Pipfile Pipfile.lock \
        poetry.lock uv.lock pdm.lock constraints*.txt 2>/dev/null

     # Recursive — multi-package repos (Lambda monorepos, CDK / Serverless,
     # multi-service workspaces). Excludes vendored / cache dirs.
     find . \( -name 'requirements*.txt' -o -name 'requirements*.in' \
              -o -name 'pyproject.toml' -o -name 'Pipfile' \
              -o -name 'Pipfile.lock' -o -name 'poetry.lock' \
              -o -name 'uv.lock' -o -name 'pdm.lock' \
              -o -name 'constraints*.txt' \) \
       -not -path '*/node_modules/*' -not -path '*/\.venv/*' \
       -not -path '*/venv/*' -not -path '*/__pycache__/*' \
       -not -path '*/\.git/*' -not -path '*/\.serverless/*' \
       -not -path '*/build/*' -not -path '*/dist/*' 2>/dev/null | sort
     ```
     Dependabot raises one alert per committed manifest, so the same package vulnerable in 3 per-Lambda `requirements.txt` files surfaces as 3 alerts. Per the "Same package in multiple manifests" rule in the branching strategy, the default fix is **one PR touching every affected manifest**.
   - **`pyproject.toml` PM tables** — a single `pyproject.toml` may carry config for more than one PM. Grep for the tables to see which are in play:
     ```bash
     rg -n '^\[(tool\.(poetry|pdm|uv)|project|build-system)\]' pyproject.toml 2>/dev/null
     ```
   - **CI / container / framework install commands** — grep CI configs, Dockerfiles, AND Python-deploy framework manifests for the actual install command. Lambda repos especially deploy pip *implicitly* through a framework plugin, not an explicit `pip install` line:
     ```bash
     rg -tg '*.yml' -tg '*.yaml' \
       '\b(pip (install|sync)|poetry (install|lock|sync)|uv (sync|pip|lock)|pdm (install|sync|lock)|pipenv (install|sync|lock)|pip-compile)\b' \
       .github .gitlab-ci.yml Dockerfile* docker-compose*.yml circle.yml .circleci \
       serverless.yml serverless.yaml template.yaml template.yml \
       cdk.json samconfig.toml 2>/dev/null
     ```
   - **Implicit-resolve Python frameworks** — common deploy patterns where pip is invoked by a plugin/framework, not directly. The `pip install` line won't appear in CI; the framework manifest is the real driver:
     - **Serverless Framework** (`serverless.yml` + `serverless-python-requirements` plugin) — each Lambda function may carry its own `requirements.txt`; plugin auto-resolves on `sls deploy`. Look for `fileName:` keys pointing at `requirements*.txt` paths and per-function `package:` blocks.
     - **AWS SAM** (`template.yaml`) — each Lambda function's `CodeUri:` directory may contain its own `requirements.txt`; `sam build` calls pip per function.
     - **AWS CDK** (`cdk.json` + `app.py`) — Python Lambdas built via the `PythonFunction` construct or Docker bundling; per-construct `requirements.txt` resolved at synth/deploy time.
     - **Zappa** (`zappa_settings.json`) — single-project pip deploy.

     These patterns hide the per-Lambda manifest split behind the framework. The recursive `find` above will surface every `requirements*.txt`; cross-reference each with the deploy manifest to figure out which Lambda owns it.
   - **Compare** committed manifests against CI install commands. If CI uses a different PM than the committed lockfile (e.g. `poetry.lock` committed but the Dockerfile runs `pip install -r requirements.txt`), expand the override + parity matrix accordingly (see "Override pattern" and "Verify (Parity Check)").
   - **Hash-pinned requirements flag** — if any `requirements*.txt` contains `--hash=sha256:` lines, this is a `pip-tools --generate-hashes` setup. Bumps require regenerating hashes; forgetting will break `pip install --require-hashes` in CI/prod.
   - **Don't ask the user up-front to classify the PM setup.** They often only know half the picture (their local context, not CI; or vice versa). Detect from manifest/lockfile + CI grep, show what was found, and ask only to confirm anomalies (e.g. *"I see `poetry.lock` committed but the Dockerfile runs `pip install -r requirements.txt` — confirm both are intentional?"*).
2. **Fetch alerts**:
   - Repo URL → `gh api "repos/<org>/<repo>/dependabot/alerts?state=open&per_page=100"`
   - Org URL → only after explicit user confirmation, then `gh api "orgs/<org>/dependabot/alerts?state=open&per_page=100"` (paginates across every repo).
   - Filter `.dependency.package.ecosystem == "pip"` for this skill; surface non-Python alerts as out-of-scope.
   - Dedupe by `(repo, package)`.
   - **Mixed-ecosystem repos (Python + npm, Go + Python, etc.):** group alerts by ecosystem BEFORE presenting the ranked table. Output out-of-scope ecosystems as a separate blocked section at the top — e.g. "⛔ Out of scope for this skill (handle separately): axios × 6 (npm), lodash × 2 (npm)." The user needs to see what's NOT being covered so they can act on it elsewhere. Never silently drop non-Python alerts.
   - **System-package false positives**: Dependabot's `pip` ecosystem occasionally flags packages installed via apt / Docker base images, not pip. Before applying, verify the package actually appears in pip's resolved tree (in the lockfile or `pip list` output). If absent from pip but present in the system, the fix is a base-image bump, not a pip override.
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
10. **Edit the manifest(s)** — write the override into *every* PM detected in step 1 (see "Override pattern"). Required in BOTH modes. Preserve environment markers (`; python_version >= '3.10'`) and extras (`cryptography[ssh]`) when editing.
11. **Regenerate every relevant lockfile** — for each PM detected in step 1, run its lockfile-only regen. For PMs without a committed lockfile (e.g. raw `pip install -r` setups), regenerate a temp lockfile *just for the parity check* and **delete it before commit** (see "Verify (Parity Check)"). No "primary" lockfile.
12. **Parity check** — for each PM detected in step 1, read its lockfile and assert every PM resolved to the *same* version of the target package. **Mismatch → abort PR in BOTH modes.** See "Verify (Parity Check)" for the commands.
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

> **CVSS=0 fallback.** Dependabot returns `security_advisory.cvss.score: 0` (or `null`) when the advisory hasn't been scored yet — common for fresh GHSAs. Don't let an unscored alert sink to the bottom of a CVSS-sorted ranking; fall back to `security_advisory.severity` (always populated). Approximate score mapping: `critical` ≈ 9.5, `high` ≈ 7.5, `medium` ≈ 5.0, `low` ≈ 2.0. Surface the fallback explicitly in the ranked table — e.g. `cvss: — (high)` rather than `cvss: 0` — so the user understands why a high-severity alert sits above a low-CVSS one.

## Exposure Mapping

Replaces the prior heuristic "reachability" model. Goal: stop trying to PROVE a vuln is unreachable — false negatives are dangerous. Instead, enumerate every import site of the target package and bucket each one. The user makes the final risk call from the surface area.

### Categories

Two categories (the JS skill's Client-Bundle drops — Python rarely ships to a browser):

| Category | Definition | Example file paths |
|---|---|---|
| **Public/API** | Code that serves HTTP/RPC/webhook traffic from outside the trust boundary. Attacker-controlled input flows in. | Django `views.py` / `urls.py` / `middleware.py` / `consumers.py` (ASGI), FastAPI / Flask / Starlette route decorators, AIOHTTP handlers, gRPC servicers, Lambda entry handlers, Celery tasks consuming external input, `wsgi.py` / `asgi.py` entrypoints |
| **Internal/Dev** | Build, tooling, scripts, tests, configs. Does NOT run in prod request path. | `setup.py`, `setup.cfg`, `pyproject.toml [build-system]`, `conftest.py`, `tests/`, `scripts/`, `tox.ini`, `noxfile.py`, Sphinx config, Makefile-driven scripts |

> Streamlit / Gradio / Dash apps ship Python server-side — treat as Public/API. PyScript / Brython are rare Python-in-browser cases; if encountered, route through the JS skill's Client-Bundle lens.

### How to enumerate import sites

PyPI distribution name does NOT always match the Python import name. Common mismatches:

| PyPI distribution | Python import |
|---|---|
| `PyYAML` | `yaml` |
| `Pillow` | `PIL` |
| `opencv-python` | `cv2` |
| `scikit-learn` | `sklearn` |
| `beautifulsoup4` | `bs4` |
| `python-dateutil` | `dateutil` |
| `protobuf` | `google.protobuf` |
| `python-jose` | `jose` |

Resolve dist→import via `importlib.metadata.packages_distributions()` (Python 3.10+; use the `importlib_metadata` backport for 3.8/3.9):

```bash
python -c "from importlib.metadata import packages_distributions; \
  d=packages_distributions(); \
  print(sorted({m for m, dists in d.items() if '<dist>' in dists}))"
```

Then grep with each import name:

```bash
# Prefer ripgrep (fast, respects .gitignore)
rg -t py "^[[:space:]]*(import|from)[[:space:]]+<import-name>([. ]|$)" -l | sort -u

# Fallback to grep
grep -rE "^[[:space:]]*(import|from)[[:space:]]+<import-name>([. ]|$)" \
  --include='*.py' -l . | grep -v -E '/(\.venv|venv|__pycache__|\.tox|\.eggs|build|dist)/' | sort -u
```

Then bucket each path by matching against the Categories table. Paths that don't fit cleanly → ask the user, do not guess.

### How to present to the user

Output as a surface summary, not a verdict:

```
Exposure surface for requests in webhook-api:
  Public/API     : 8 sites (e.g. app/routes/webhook.py, services/external_client.py, ...)
  Internal/Dev   : 2 sites (e.g. tests/conftest.py, scripts/seed_data.py, ...)
```

If a single import site straddles categories (e.g. a util re-exported from both a route handler and a test helper), it inherits the highest-risk category present.

The user reads the surface and decides whether the bump is worth the risk — Claude does not say "this is reachable" or "this is unreachable".

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

1. **Dedupe**: GitHub raises one alert per committed manifest/lockfile. A repo with both `requirements.txt` AND `pyproject.toml` may raise two alerts for the same vuln. Fix the package once; cover every PM in the override.
2. **Get advisory**: `gh api repos/<org>/<repo>/dependabot/alerts/<n>` — extract `first_patched_version`, `vulnerable_version_range`, and `cvss.score`. The list endpoint hides these. For clusters, fetch every alert in the cluster. Python advisories may have a GHSA identifier only (no CVE) — accept GHSA-prefix advisories the same way.
3. **Locate**: direct dep (in `pyproject.toml` / `requirements*.in` / `Pipfile [packages]`) or transitive? Parse the relevant lockfile.

   > **`tomllib` requires Python ≥ 3.11.** For 3.10, `pip install tomli` and replace `import tomllib` with `import tomli as tomllib` (or use a try/except shim). The top-level `[[package]]` array key is the same across poetry / uv / pdm lockfiles, but each PM's *inner* `dependencies` field has a **different shape** — separate snippets per PM:

   ```bash
   # poetry.lock — [package.dependencies] is a TOML TABLE (dict)
   #   dep_name = "version-spec"  OR  dep_name = { version = "...", ... }
   python -c "import tomllib; d=tomllib.load(open('poetry.lock','rb')); \
     print([(p['name'], p['version']) for p in d.get('package',[]) \
            if '<pkg>' in (p.get('dependencies') or {})])"

   # uv.lock — package.dependencies is a LIST of inline tables with .name
   #   dependencies = [{ name = "foo" }, { name = "bar", marker = "..." }]
   python -c "import tomllib; d=tomllib.load(open('uv.lock','rb')); \
     print([(p['name'], p['version']) for p in d.get('package',[]) \
            if any(dep.get('name')=='<pkg>' for dep in (p.get('dependencies') or []))])"

   # pdm.lock — package.dependencies is a LIST of PEP 508 requirement STRINGS
   #   dependencies = ['foo>=1.0', 'bar; python_version >= "3.10"']
   python -c "import tomllib, re; d=tomllib.load(open('pdm.lock','rb')); \
     print([(p['name'], p['version']) for p in d.get('package',[]) \
            if any(re.match(r'^<pkg>(?:[<>=!~\[\(;\s]|$)', s) \
                   for s in (p.get('dependencies') or []))])"

   # Pipfile.lock — JSON
   jq '(.default + .develop) | to_entries[]
       | select(.value.dependencies // {} | has("<pkg>"))
       | {name: .key, version: .value.version}' Pipfile.lock
   ```
4. **Exposure Mapping**: see "Exposure Mapping" section. Categorize every import site (Public/API · Internal/Dev) and produce a surface summary for the user.
5. **Pick version (defensive minimal-patched, PEP 440)**:
   - Single alert: `>=X.Y.Z,<(X+1).0.0` of `first_patched_version`.
   - Cluster: same shape, `X.Y.Z = max(first_patched_version)` across every CVE in the cluster — i.e. the *minimal* version that supersets every patch. Compute via:
     ```bash
     for n in <alert-numbers>; do
       gh api repos/<org>/<repo>/dependabot/alerts/$n \
         --jq '.security_advisory.vulnerabilities[0].first_patched_version.identifier'
     done | python -c "import sys; from packaging.version import Version; \
       vs=[Version(l.strip()) for l in sys.stdin if l.strip()]; print(max(vs))"
     ```
   - **Verify the target isn't yanked**:
     ```bash
     curl -s "https://pypi.org/pypi/<pkg>/json" \
       | jq -r --arg t '<target>' \
           '{yanked: (.releases[$t] | map(.yanked) | any),
             reasons: (.releases[$t] | map(.yanked_reason) | unique - [null])}'
     # → {"yanked": false, "reasons": []} expected.
     # → any file in the release yanked → pick the next release up.
     ```
     Per-file yanked status *should* be consistent across a release's artifacts, but isn't guaranteed; the `any` form catches the inconsistent case too.
   - **Verify `requires_python` compatibility**:
     ```bash
     curl -s "https://pypi.org/pypi/<pkg>/<target>/json" | jq -r '.info.requires_python'
     ```
     If the target's floor exceeds the project's configured floor (`project.requires-python` or `tool.poetry.dependencies.python` in `pyproject.toml`), the bump breaks install on older deploy targets. Surface to user.
   - **Wheel availability across deploy targets** — for compiled packages (cryptography, lxml, numpy, pandas, pillow, psycopg2, cffi, bcrypt, pyarrow, grpcio), list available wheels:
     ```bash
     curl -s "https://pypi.org/pypi/<pkg>/<target>/json" \
       | jq -r '.urls[].filename' | grep -E '\.whl$' | sort
     ```
     Verify wheels exist for every target platform tag (`manylinux2014_x86_64`, `manylinux2014_aarch64`, `musllinux_*`, `macosx_*`, `win_amd64`) AND every Python version in the project's `requires-python` matrix (read from `project.requires-python` in `pyproject.toml`, or the project's CI test matrix). A missing wheel forces a source build on that target — silent CI break (slow build, may fail without compiler/headers).
   - **Do NOT default to "latest in same major."** Latest maximizes change surface and risks breaking transitives. Only override the defensive minimum when (a) the user explicitly asks, or (b) the minimum is unmaintained / yanked / pulls in its own fresh CVEs.
   - Cap at the same major as currently installed unless the user approves a major bump.
6. **Changelog scrape** — fetch release notes between current and target version. Try PyPI's project metadata first, then the upstream GitHub:
   ```bash
   # 1. Pull PyPI project URLs — Changelog / Release notes are commonly listed
   curl -s "https://pypi.org/pypi/<pkg>/json" | jq -r '.info.project_urls'

   # 2. If a GitHub repo is listed, fetch release notes via gh.
   #    Strip trailing .git separately — repo names can contain dots
   #    (org/foo.bar is valid), so the second path segment is [^/]+, not [^/.]+.
   PKG_REPO=$(curl -s "https://pypi.org/pypi/<pkg>/json" \
     | jq -r '.info.project_urls.Source // .info.project_urls.Repository // .info.project_urls.Homepage // .info.home_page // empty' \
     | sed -E 's|.*github\.com/([^/]+/[^/]+).*|\1|; s|\.git$||')
   # Guard against null / non-github URLs — jq's // null cascade can yield "null"
   # as a literal string, and projects hosted on GitLab / Codeberg / self-hosted
   # don't match the sed pattern. Skip the gh path cleanly in those cases.
   if [[ -n "$PKG_REPO" && "$PKG_REPO" != "null" && "$PKG_REPO" == */* ]]; then
     gh release view "v<target>" --repo "$PKG_REPO" --json tagName,body,createdAt 2>/dev/null \
       || gh release view "<target>" --repo "$PKG_REPO" --json tagName,body,createdAt
   else
     echo "no GitHub repo found for <pkg> on PyPI — skipping gh release path; falling back to sdist changelog grep below"
   fi

   # 3. Fallback: download the sdist and grep the bundled CHANGELOG.
   #    Resolve the sdist URL from the same PyPI JSON — distribution-name
   #    normalization (PyYAML → pyyaml, python-dateutil → python_dateutil)
   #    makes hand-guessed filenames unreliable.
   SDIST_URL=$(curl -s "https://pypi.org/pypi/<pkg>/<target>/json" \
     | jq -r '.urls[] | select(.packagetype=="sdist") | .url' | head -1)
   if [[ -n "$SDIST_URL" ]]; then
     SRC=/tmp/<pkg>-<target>
     mkdir -p "$SRC" && curl -sL "$SDIST_URL" -o "$SRC/sdist.tar.gz"
     tar -xf "$SRC/sdist.tar.gz" -C "$SRC" --strip-components=1
     grep -inrE 'BREAKING|DEPRECATED|MIGRATION|removed|drop(ped)? support' \
       --include='CHANGELOG*' --include='CHANGES*' \
       --include='HISTORY*' --include='NEWS*' "$SRC" 2>/dev/null | head -50
   else
     echo "no sdist published for <pkg>==<target> — wheel-only release; skip sdist changelog fallback"
   fi
   ```
   Surface the flagged lines verbatim to the user — do not paraphrase. If `BREAKING` / `DEPRECATED` / `MIGRATION` appears, raise the safety interlock to "second confirmation required" before proceeding.

   **Transitive-dep qualifier:** Before demanding a second confirmation, check whether the flagged package has any direct import sites in source (from the Exposure Mapping step). If zero direct imports exist — the package is purely transitive — state this explicitly alongside the flag: *"This flag appears in a package that is not directly imported by your source code. The breaking change is unlikely to affect you unless your code parses its error messages or hooks into its internals."* This collapses two confirmation rounds into one when the flag is clearly irrelevant to the calling code.
7. **Safety interlock — PAUSE.** Print to the user:
   - chosen target version + reason (defensive minimal vs latest, why)
   - exposure surface (counts per category, sample paths)
   - changelog flags (verbatim lines, or "no flags" if clean)
   - wheel-availability check result (if the package is compiled)
   - `requires_python` skew flag (if the target's floor exceeds the project's)

   Wait for explicit go-ahead. If changelog flags were raised, require an unambiguous "yes, continue" / "I've handled it" — silence or ambiguous reply means stop.

8. After user OK: edit manifest(s), regen lockfile(s), run Parity Check, commit, ask before push.

## Override pattern (Python)

Use overrides for:
- **Transitive vulns** — package not in `[project.dependencies]` / `[tool.poetry.dependencies]` / `[packages]`. The override mechanism is the only fix without bumping a parent.
- **Direct deps where transitives ALSO request the package** — bumping the direct dep doesn't guarantee transitives get the same resolved version (the resolver may pick a different one for a transitive's range). Add the override anyway as defense-in-depth.

### Dual-write is MANDATORY

Write the override field for **every PM detected in step 1**. Different PMs honor *different* mechanisms — and crucially, **raw pip and pipenv have NO transitive-override mechanism at all**:

| PM | Override mechanism | Regen command |
|---|---|---|
| pip (raw) | NO TRANSITIVE OVERRIDE — pin the package directly in `requirements.txt`, or use a `constraints.txt` referenced via `pip install -c constraints.txt` | `pip install -r requirements.txt -c constraints.txt` (no committed lockfile — temp resolve for parity check only) |
| pip-tools | Edit `requirements.in` (or add a constraint); `pip-compile` re-resolves into `requirements.txt` | `pip-compile requirements.in` (add `--generate-hashes` if the existing file uses hashes) |
| poetry | `[tool.poetry.dependencies]` for direct pin. For a transitive, poetry has no override *field* — `poetry add <pkg>@>=X.Y.Z,<(X+1).0.0` adds it as an explicit direct dep (the only mechanism). | `poetry lock --no-update` |
| uv | `[tool.uv] override-dependencies = ["<pkg>>=X.Y.Z,<(X+1).0.0"]` | `uv lock` |
| pdm | `[tool.pdm.resolution] overrides = { "<pkg>" = ">=X.Y.Z,<(X+1).0.0" }` | `pdm lock` |
| pipenv | Edit `[packages]` in `Pipfile` for direct pin; NO transitive override mechanism | `pipenv lock` |

Writing to only one when more than one PM is in play produces **environment drift**: developers see one resolved version locally, CI ships another. This is exactly the bug class this skill exists to prevent. Write the override into every relevant field with the same target range, every time, even if only one lockfile is currently committed.

A common Python pattern in this org: `poetry.lock` committed for local dev + an exported `requirements.txt` consumed by the prod Docker image. Both manifests must carry the override (poetry's `[tool.poetry.dependencies]` direct pin AND the regenerated `requirements.txt` from `poetry export`).

### No-transitive-override case (raw pip / pipenv only)

If the only PMs in play are raw pip and/or pipenv, AND the bump is transitive (the vulnerable package is not a direct dep), there is no override mechanism available. The fix paths are:

1. **Bump the parent dep** that pulls in the vulnerable transitive — if the parent's newer version has migrated to a patched range. (Often the right answer.)
2. **Migrate to a PM with overrides** (uv or pdm) — a project-level change, out of scope for a single security PR.
3. **Add the transitive as an explicit direct dep** with the patched pin in `requirements.txt` / `Pipfile [packages]`. Surface to the user: this changes the dep graph and may not be the right answer if the parent later drops the transitive.

**Fast-Track is hard-ineligible in this case** — the no-override-mechanism constraint forces option (1) or (3), which deserve Standard's full visibility (changelog scrape + exposure surface + safety interlock).

### Preserve environment markers and extras

When applying the override, preserve any environment markers and extras already present on the dep:

```toml
# Before
"<pkg>[extra1,extra2] ; python_version >= '3.10' and platform_system != 'Windows'"

# After (override applied as version pin)
"<pkg>[extra1,extra2]>=X.Y.Z,<(X+1).0.0 ; python_version >= '3.10' and platform_system != 'Windows'"
```

Dropping the marker silently widens install scope (the dep installs on platforms/Python versions it shouldn't); dropping extras silently disables feature-gated functionality.

## Version range rules

- **Default to defensive minimal patched.** Use `>=X.Y.Z,<(X+1).0.0` where `X.Y.Z` is the *minimal* version that supersets every applicable CVE patch (single alert: `first_patched_version`; cluster: `max(first_patched_version)` across the cluster). Universal across pip, poetry, uv, pdm, pipenv. Latest-in-major is opt-in only — its larger change surface raises the chance the bump itself breaks something.
- **PEP 440 ≠ semver.** Critical syntax differences:
  - **No universal `^`.** The semver caret is poetry-only — `^X.Y.Z` works in `[tool.poetry.dependencies]`, nowhere else. Use the explicit `>=X.Y.Z,<(X+1).0.0` form for portability across uv / pdm / pip / pipenv.
  - **PEP 440 `~=X.Y.Z`** ("compatible release") is *narrower* than the semver caret: `~=X.Y.Z` means `>=X.Y.Z,<X.(Y+1).0`, i.e. patch-only flexibility. Use only when minor-bump flexibility is unwanted.
  - **Exact pin `==X.Y.Z`** is common in `requirements.txt` for reproducibility. Surface the trade-off to the user (no patch-level updates ride in) before defaulting to exact pin. A hash-pinned `requirements.txt` already has reproducibility via `--require-hashes`; layering `==` on top is redundant unless the project explicitly forbids re-resolves.
- **For `uv override-dependencies` and `pdm overrides`**, use the full PEP 440 specifier with an upper bound (`<pkg>>=X.Y.Z,<(X+1).0.0`). A bare distribution name with no version part is invalid; an unbounded `>=X.Y.Z` *is* accepted by uv but lets a future major bump ride in silently — same anti-pattern as JS bare `>=` without a caret. Always cap.
- **Never bare `>=X.Y.Z`** without an upper bound — surprise major bumps. Always cap.
- **Never `>X.Y.Z`** — excludes the patched version itself, forces `X.Y.Z+1`, no benefit.
- **Pre-release versions** (`1.0.0a1`, `.rc1`, `.dev1`) are excluded by pip's default resolver unless `--pre` is passed or an exact `==` pin is used. If the only patched version is a pre-release, flag this explicitly — the project may need to opt in to pre-releases or wait for the stable.
- If the defensive minimum is yanked, unmaintained, or itself triggers fresh CVEs, escalate to the user — present the next-newest candidate plus its changelog scrape and let the user pick.

## Verify (Parity Check)

Two checks. Both must pass before the PR is opened. Run for **every PM detected in step 1**, not just one.

### 1. Patched-version resolution

For each detected PM, confirm it resolves the target package to `>= minimal_patched_version`. Read the lockfile directly — most reliable, robust to lockfile format quirks. PyPI distribution names are case-insensitive and normalize (`_` / `-` / `.` collapse), so lower-case + replace before comparing names:

```bash
PKG_NORM=$(printf '%s' '<pkg>' | tr '[:upper:]_.' '[:lower:]--' | tr -s '-')

# poetry: parse poetry.lock (TOML)
POETRY_VER=$(python - <<EOF
import tomllib
d=tomllib.load(open('poetry.lock','rb'))
def norm(n): return n.lower().replace('_','-').replace('.','-')
print(next((p['version'] for p in d.get('package',[]) if norm(p['name'])=='$PKG_NORM'), ''))
EOF
)

# uv: parse uv.lock (TOML)
UV_VER=$(python - <<EOF
import tomllib
d=tomllib.load(open('uv.lock','rb'))
def norm(n): return n.lower().replace('_','-').replace('.','-')
print(next((p['version'] for p in d.get('package',[]) if norm(p['name'])=='$PKG_NORM'), ''))
EOF
)

# pdm: parse pdm.lock (TOML, same shape as uv.lock)
PDM_VER=$(python - <<EOF
import tomllib
d=tomllib.load(open('pdm.lock','rb'))
def norm(n): return n.lower().replace('_','-').replace('.','-')
print(next((p['version'] for p in d.get('package',[]) if norm(p['name'])=='$PKG_NORM'), ''))
EOF
)
# Alternative: pdm list --json | jq

# pipenv: parse Pipfile.lock (JSON, version pinned with leading "==")
PIPENV_VER=$(jq -r --arg p '<pkg>' \
  '(.default[$p].version // .develop[$p].version // "")' Pipfile.lock \
  | sed -E 's/^==//')

# pip (raw) / pip-tools: read requirements.txt — only meaningful if pinned exactly
PIP_VER=$(grep -iE '^<pkg>==' requirements.txt 2>/dev/null \
  | head -1 | sed -E 's/^[^=]+==//; s/[[:space:];].*$//')

echo "poetry=$POETRY_VER uv=$UV_VER pdm=$PDM_VER pipenv=$PIPENV_VER pip=$PIP_VER"
```

Use only the variables for PMs actually in play; ignore the rest. All values must show the patched version (or higher).

> **Note: a `requirements.txt` with `<pkg>>=X.Y.Z` (no exact `==`) is NOT a lockfile** — it re-resolves on every `pip install`. The parity check needs a pinned-exact value to be meaningful. If the project's `requirements.txt` uses `>=` ranges, treat that PM as having no committed lockfile and generate a temp resolution for the parity check (see next subsection).

### Generating a temp lockfile (PMs without a committed lockfile)

When CI uses a PM that has no committed lockfile (e.g. poetry-local + raw-pip-CI), generate a temp lockfile *just for the parity check*, then **delete it before commit**:

| PM | Lockfile-only regen | Resulting file |
|---|---|---|
| poetry | `poetry lock --no-update` | `poetry.lock` |
| uv | `uv lock` | `uv.lock` |
| pdm | `pdm lock --no-sync` | `pdm.lock` |
| pipenv | `pipenv lock` | `Pipfile.lock` |
| pip-tools | `pip-compile requirements.in` (add `--generate-hashes` if hashed) | `requirements.txt` |
| pip (raw) | `python -m pip install '<pkg>>=X.Y.Z' --dry-run --report /tmp/pip-resolve.json --quiet`, then `jq '.install[] | select(.metadata.name=="<pkg>") | .metadata.version' /tmp/pip-resolve.json` — **requires pip ≥ 23.2** (the `--report` JSON format landed in 23.2). Verify with `pip --version` first; older pip silently produces no report. | (JSON report only, no file commit) |

> ⚠ Do **NOT** commit a generated lockfile from a PM that doesn't already have one committed. Dual-lockfile drift is exactly the bug class this skill exists to prevent — a generated `requirements.txt` alongside an authoritative `poetry.lock` will silently diverge on the next regen and you've doubled the surface area, not halved it.

When no lockfile is committed for a detected CI PM, also explicitly assert:

- The override field for that PM is present in the manifest (see PM table in "Override pattern → Dual-write is MANDATORY").
- The direct-dep range for the target package (if it's a direct dep) is consistent with the override.

### 2. Lockfile parity (MANDATORY — abort PR on mismatch)

```bash
# Collect non-empty resolved versions across all detected PMs
VERS=$(printf '%s\n' "$POETRY_VER" "$UV_VER" "$PDM_VER" "$PIPENV_VER" "$PIP_VER" \
  | grep -v '^$' | sort -u)
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

- Override missing from one of the PMs (most common — e.g. `[tool.uv] override-dependencies` written but `[tool.pdm.resolution] overrides` forgotten).
- Poetry resolved the bump but the exported `requirements.txt` is stale — re-run `poetry export -o requirements.txt --without-hashes` (or with hashes if the project uses them).
- `pip-tools` `requirements.txt` not regenerated after `requirements.in` edit — re-run `pip-compile`.
- Hash-pinned `requirements.txt` left with stale hashes after a bump (will manifest as a `pip install --require-hashes` failure in CI, not as a version mismatch — regenerate hashes via `pip-compile --generate-hashes`).
- `requires_python` skew — one PM's resolver picked an older version because the target's Python floor exceeds that PM's configured Python.

Environment drift between dev and CI/CD (any PM pair: poetry-local + pip-CI, uv-local + pdm-CI, pipenv-local + raw-pip-CI, etc.) is the bug class this skill exists to prevent. The Parity Check is non-negotiable.

### Don't trust install stdout

`poetry lock --no-update` may print `No changes` even when the override forced a re-resolution and the lockfile actually changed. Same for `uv lock`, `pdm lock`, `pipenv lock` in some edge cases. ALWAYS run the verify commands above — they read the lockfile directly.

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

- **Native-wheel risk**: bumps of compiled packages (`cryptography`, `lxml`, `numpy`, `pandas`, `pillow`, `psycopg2`, `cffi`, `bcrypt`, `pyodbc`, `pyarrow`, `grpcio`) can drop a platform wheel between versions. Verify wheels exist for every deploy-target platform tag (`manylinux2014_x86_64`, `manylinux2014_aarch64`, `musllinux_*`, `macosx_*`, `win_amd64`) AND every Python version in the project's `requires-python` matrix (read from `project.requires-python` in `pyproject.toml`, or the project's CI test matrix) before pinning. A missing wheel forces a source build on that target — silent CI break (slow build, may fail without compiler/headers).
- **Hash mismatches**: when dev and CI use different index URLs (private PyPI mirror, devpi), hash-pinned requirements can fail with `hash mismatch` — same file, different mirror's hash. Surface this if a hash check fails on a bump that otherwise looks correct.
- **`requires_python` skew**: bumping to a target whose `requires_python` floor exceeds the project's configured floor (`project.requires-python` / `tool.poetry.dependencies.python`) breaks install on older Python deploys. Check the target's `requires_python` via PyPI metadata before pinning.
- **Distribution-name normalization**: PyPI normalizes `_` / `-` / `.` and case in distribution names. `pkg_a`, `pkg-a`, `Pkg.A` all refer to the same distribution at resolve time, but lockfile entries may use any of these spellings. When parsing lockfiles, normalize both sides (`.lower().replace('_','-').replace('.','-')`) before comparing names.
- **Conda environments**: if the project also ships a `conda` env (`environment.yml` or `conda-lock.yml`), the conda channel may carry a different version of the package than PyPI. Out of scope for this skill — flag to user but don't try to fix.
