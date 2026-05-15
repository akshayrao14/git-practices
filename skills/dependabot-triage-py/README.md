# dependabot-triage-py (v2.1)

[![skills.sh](https://skills.sh/akshayrao14/dependabot-triage-py)](https://skills.sh/akshayrao14/dependabot-triage-py)

> **Note:** Python-specific workflow content (PM detection, override pattern, exposure categories, PEP 440 version syntax, per-PM parity-check commands, native-wheel platform notes) is fleshed out. A small number of examples in the shared-fragment sections still reference JS packages (`axios`, `dompurify`) — those are illustrative, not load-bearing; the concepts apply to Python ecosystems. For the JS sibling, see [dependabot-triage](https://github.com/akshayrao14/dependabot-triage).

Agent Skill for triaging and fixing Dependabot vulnerability alerts in Python repos. Covers pip, poetry, uv, pdm, pipenv ecosystems. Compatible with any agent that supports the [Agent Skills standard](https://github.com/anthropics/skills) — Claude Code, Codex CLI, Gemini CLI, Cursor, etc.

## Install

```bash
npx skills add akshayrao14/dependabot-triage-py
```

Installs into the right skills dir for your agent (Codex `~/.codex/skills/`, Claude Code `~/.claude/skills/`, or open-standard `~/.agents/skills/`). Restart your agent session afterward.

## What it does

Given a Dependabot alert (URL, alert number, or just the package name), Claude will:

1. Fetch the alert + advisory via `gh api`.
2. **Filter by ecosystem first.** For mixed-ecosystem repos (Python + npm, Go + Python, etc.), group alerts by ecosystem and output out-of-scope ones as a blocked section before the ranked table. Non-Python alerts are never silently dropped.
3. Rank open pip alerts using a three-axis framework (Impact × Exposure × CVSS).
4. **Map exposure** — enumerate every import site of the target package and bucket each into Public/API · Internal/Dev. (Python skill drops the Client-Bundle category that the JS skill uses — Python rarely ships to browsers.)
5. **Pick a defensive minimal-patched version** — the smallest version that supersets every CVE patch in the cluster (not "latest"), expressed as a PEP 440 range `>=X.Y.Z,<(X+1).0.0`.
6. **Scrape the changelog** between current and target version, flagging `BREAKING` / `DEPRECATED` / `MIGRATION` keywords.
7. **PAUSE for explicit user OK** before applying the bump.
8. **Detect every PM in play** by inspecting committed manifests/lockfiles AND CI install commands (`.github/workflows`, Dockerfiles, etc.). Write the override into the field for every detected PM (uv `override-dependencies`, pdm `overrides`, poetry direct pin, pip constraints.txt). Regenerate every relevant lockfile.
9. **Run a parity check across every PM.** If any pair resolves to different versions of the target package, abort and surface the mismatch — do not open the PR.
10. Open a PR off the latest remote base branch.

Full behavior spec is in [`SKILL.md`](./SKILL.md).

## Why a separate skill from `dependabot-triage`?

Python override semantics differ fundamentally from JavaScript:

- **Raw pip and pipenv have no transitive-override mechanism.** uv (`override-dependencies`) and pdm (`overrides`) do; poetry pins transitives only via explicit direct-add. Mixing these into the JS skill's npm/pnpm/yarn override-field abstraction produces incorrect advice.
- **PEP 440 version syntax differs from semver.** `^X.Y.Z` (semver caret) is poetry-only; cross-PM Python work uses `>=X.Y.Z,<(X+1).0.0` or `~=X.Y.Z` (PEP 440 compatible release).
- **Distribution name ≠ import name.** `PyYAML` imports as `yaml`, `Pillow` as `PIL`, `opencv-python` as `cv2`. Import-site enumeration must map dist→module before grepping.
- **Native-wheel risk.** Bumps of compiled packages (`cryptography`, `lxml`, `numpy`, `pandas`, `pillow`, `psycopg2`) can drop a platform wheel between versions; needs platform/Python-version verification before pinning.
- **Hash-pinned requirements.** pip-tools `--generate-hashes` requires regenerating hashes after any bump; forgetting breaks `pip install --require-hashes` silently in dev, loudly in prod.

## Fast-Track mode

Same shared mode mechanics as the JS skill — see the [Fast-Track section in `SKILL.md`](./SKILL.md#fast-track-mode). One Python-specific hard ineligibility: if the project uses raw pip or pipenv only AND the bump is transitive (no override mechanism available), Fast-Track is refused regardless of CVSS — the only fix path is bumping the parent dep, which deserves Standard's full visibility.

## Exposure Mapping categories

Two-category model (the JS skill's Client-Bundle category is dropped):

| Category | Definition | Example file paths |
|---|---|---|
| **Public/API** | Code that serves HTTP/RPC/webhook traffic from outside the trust boundary. | Django `views.py` / `urls.py` / `middleware.py` / `consumers.py`, FastAPI/Flask/Starlette route decorators, AIOHTTP handlers, gRPC servicers, Lambda entry handlers, Celery tasks consuming external input, `wsgi.py` / `asgi.py` entrypoints |
| **Internal/Dev** | Build, tooling, scripts, tests, configs — does not run in prod request path. | `setup.py`, `setup.cfg`, `pyproject.toml [build-system]`, `conftest.py`, `tests/`, `scripts/`, `tox.ini`, `noxfile.py`, Sphinx config |

Streamlit / Gradio / Dash apps ship Python server-side — treat as Public/API. PyScript and Brython are the rare Python-in-browser cases; encountered, route through the JS skill's Client-Bundle lens.

## Parity Check

Generalizes the JS skill's check: every Python PM detected in the CI / lockfile inspection step must resolve the target package to the same version. The skill reads each lockfile (or queries the PM directly) and compares:

```
poetry → 2.31.0
uv     → 2.31.0
PARITY OK
```

vs

```
poetry → 2.31.0
pip    → 2.28.1
PARITY ABORT
```

A mismatch aborts the PR. The full per-PM command set lives in [`SKILL.md`](./SKILL.md#verify-parity-check).

## Prerequisites

- `gh` CLI authenticated against the target repo (`gh auth status`).
- Local clone of the repo whose alerts you're triaging.
- `python` plus every PM the repo actually uses (across local AND CI — e.g. both `poetry` and `uv` if the repo migrated mid-flight). The parity check has to drive each PM.
- `ripgrep` (`rg`) recommended for the Exposure Mapping step + the CI workflow inspection step; falls back to `grep` if unavailable.

## Trigger phrases

Any of these route Claude to this skill (when the alert is in a Python repo):

- "Triage Dependabot alerts in `<repo>`"
- "Which vuln should I fix first? <github.com/.../security/dependabot URL>"
- "Fix Dependabot alert #<N> in this repo"
- "Bump `<pkg>` to a non-vulnerable version"

Org-wide triage requires explicit phrasing — do NOT auto-fan-out:

- "Fan out across the org"
- "Triage all repos in `<org>`"
- "Run org-wide triage"

## Multi-PR sessions

When fixing multiple packages one-PR-per-package against the same base branch, every subsequent PR will conflict on the manifest at the same overrides insertion point — this is expected and predictable. After each PR merges:

1. `git fetch origin <base>`
2. `git checkout <next-branch> && git rebase origin/<base>`
3. Resolve the conflict: keep all existing override keys, add the incoming one.
4. Regen the lockfile via the relevant PM's lockfile-only install command.
5. `git add <manifest> <lockfile> && git rebase --continue`
6. `git push --force-with-lease origin <next-branch>`

Claude handles this loop automatically — ping it after each merge.

## Updating

Re-run the install command to pull the latest version:

```bash
npx skills add akshayrao14/dependabot-triage-py
```
