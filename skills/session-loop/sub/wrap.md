# `/session-wrap` — end-of-session handoff

Two-phase procedure: **safety gate** first, **handoff write** second. Refuse to write a handoff if the world is in a state that cannot be safely paused.

## When to invoke

- User says "let's stop here", "wrap up", "end of session", "I'm done for today".
- User signals context switch ("I'll pick this up tomorrow").
- Long-running task hits a natural boundary and user confirms stop.

## Action scope (read this before doing anything)

`/session-wrap` has two distinct authorities:

- **Over user work** (source code, infra files, app config): **suggest only, never auto-fix**. If a gate fails because of user work, list the problem and stop. The user resolves it (or passes `--force` with a reason). The skill does not stage, commit, revert, or modify user-owned files.
- **Over its own artifacts** (`UPDATES.md`, ledger entries it writes, `NEXT_SESSION.md`): full authority. May write, overwrite, and commit. Never stages anything outside this artifact set. Never runs `git add .` or `git add -A`.

Keep this boundary strict. If a future change asks the skill to fix user work as a convenience, refuse — the value of the gate is that it forces the user to see and decide.

## Phase 1 — stop-safety gate

Run all checks. Surface every failure as a discrete item the user must resolve (or explicitly waive with `--force`). Do **not** proceed to phase 2 until all gates pass or `--force` is given.

**Suggest, don't fix.** Every gate failure is a *recommendation* to the user. Do not run `git add`, `git stash`, `kubectl rollout`, `helm rollback`, or any other remediating command on the user's behalf — even if the fix looks obvious. The user decides whether to clean up or `--force`.

### Gate checks

1. **Git working tree**
   - Run `git status --porcelain` and `git status -sb`.
   - **Fail if**: uncommitted changes touch files matching any of: `*.env*`, `*secret*`, `*credential*`, `*.pem`, `*.key`, `*token*`, `kubeconfig*`. These are dangerous to leave loose between sessions.
   - **Warn if**: any uncommitted changes exist at all. Not a hard fail, but list the diff summary.
   - **Fail if**: branch is detached HEAD and there are uncommitted changes.
   - **Warn if**: branch is ahead of `origin/<branch>` by more than 0 commits. Suggest push.

2. **Infrastructure-as-code drift**
   - If `terraform/` or `*.tf` present at repo root or in immediate subdirs: check for `terraform.tfstate.backup` newer than `terraform.tfstate` (mid-apply marker) — **fail**.
   - If `*.bicep` or `bicepconfig.json` present and last `az deployment` in shell history was less than 5 minutes ago: **warn** — confirm deployment completed.
   - If `Chart.yaml` or `helm/` present: check for active `helm` processes (`pgrep -laf helm` if available); if any release is `pending-upgrade` or `pending-install` (when `kubectl` and `helm` both available): **fail**.

3. **Cloud resources potentially orphaned**
   - If the conversation explicitly created cloud resources this session (look for `az`/`aws`/`gcloud` create commands in conversation context), list them and ask the user to confirm they should remain. Do not auto-fail — agents cannot reliably distinguish intentional from orphaned.

4. **Open agent-managed tasks**
   - If TaskList shows tasks in `in_progress` state: list them and **fail**. Tasks must be moved to `completed` or `cancelled` before wrap.

5. **Half-baked file edits**
   - Scan recently edited files (this session) for markers: `// TODO(this-session)`, `// XXX`, `<<<<<<< HEAD`, conflict markers. **Fail** on conflict markers, **warn** on TODO/XXX.

### Gate output

Print a table:

```
| Gate                          | Status | Detail                                  |
|-------------------------------|--------|-----------------------------------------|
| Git working tree              | PASS   |                                         |
| Sensitive uncommitted files   | FAIL   | .env.local has unstaged changes         |
| Helm release state            | PASS   |                                         |
| ...                           | ...    | ...                                     |
```

If any FAIL: stop here. Ask user to clean up, or pass `--force` to override (with a one-line reason that gets logged into the handoff).

## Phase 2 — handoff write

Only runs if phase 1 passed (or `--force`).

### Step 1: capture verification commands

Build a list of commands future-you will rerun on `/session-catchup` to confirm the world still matches. Pick the smallest set that covers what was touched this session. Examples:

- `git rev-parse HEAD` + `git status --porcelain` (always)
- `gh pr view <N> --json state,mergeable` (if a PR was opened this session)
- `kubectl -n <ns> get pods` (if AKS/EKS pods were touched)
- `az resource list --resource-group <rg> --query "[].{name:name,type:type}" -o table` (if Azure resources were touched)
- `terraform plan -detailed-exitcode` (if Terraform was applied)
- `helm list -n <ns>` (if helm was used)

Record the exact command and its output **right now**, so `/session-catchup` can diff against current reality.

### Step 2: append to `UPDATES.md`

Insert a dated entry at the **top** of `UPDATES.md` (newest-first convention). Template:

```markdown
## YYYY-MM-DD — <one-line summary of session>

### What

<2–5 sentence narrative of what was actually done this session.>

### Why

<Motivation. Skip if same as the broader project's stated motivation.>

### State at wrap

<Where things stand. Don't claim more than is true. If a deploy failed mid-way, say so.>

### Open threads (carry-forward)

- <Thread 1: what's unresolved, who/what blocks it.>
- <Thread 2: ...>
```

If `UPDATES.md` does not exist, create it with a one-line header explaining the append protocol, then add the entry.

### Step 3: append to ledger (`DECISIONS.md` / `MIGRATION_LEDGER.md` / discovered)

For each **decision made this session that wasn't already logged**, append an entry:

```markdown
## AD-NNN · YYYY-MM-DD · <decision title>

**Context**: <what triggered this decision>
**Decision**: <what we chose>
**Alternatives rejected**: <what we considered and why we didn't pick it>
**Supersedes**: <prior AD-NNN if any, else "none">
**Blast radius**: <files/services/resources affected>
**Reversibility**: <reversible | partially | irreversible — and why>
```

Number ADs sequentially from the last `AD-NNN` in the file. If none exist, start at `AD-001`.

**Do not retro-edit prior ADs.** If this session changed a prior decision, the new AD has `Supersedes: AD-<prior>` and the prior entry stays verbatim.

### Step 4: write `NEXT_SESSION.md`

**Overwrite** (not append). This file is ephemeral handoff state — the next `/session-wrap` or `/session-checkpoint` overwrites it. Use the template at `templates/NEXT_SESSION.md`. Fill every section.

### Step 5: optionally commit handoff artifacts

Wrap *may* commit its own artifacts — and only its own. The committable set is the exact files written by steps 2–4:

- `UPDATES.md`
- the chosen ledger file (`DECISIONS.md`, `MIGRATION_LEDGER.md`, etc.)
- `NEXT_SESSION.md`

Behavior:

- Default: prompt the user — `Commit handoff artifacts? [y/N]`. Default answer is `N`. If the user says no, skip the commit; they can commit manually later.
- `--auto-commit`: skip the prompt, commit immediately.
- `--no-commit`: skip the prompt, do not commit. (Useful for CI / non-interactive runs.)

When committing, use **explicit path adds** — never `git add .`, never `git add -A`:

```bash
git add UPDATES.md "<ledger-path>" NEXT_SESSION.md
git commit -m "chore(session): wrap YYYY-MM-DD"
```

If `NEXT_SESSION.md` is in `.gitignore` (some projects prefer it untracked since it is ephemeral): omit it from the `git add`. The commit still proceeds for the other two files. Print a note: `NEXT_SESSION.md is gitignored — leaving uncommitted.`

If any of the three files are unchanged (rare but possible — e.g. a re-run wrap that produces identical narrative), skip the commit and print `No artifact changes to commit.`

**Hard limits**:
- Never stage files outside the committable set.
- Never run `git push`. Wrap is local-only.
- Never amend a prior commit.
- Never run `git stash` to "set aside" dirty user work — phase 1 already refused on dirty state, so this should not arise.

### Step 6: confirm and exit

Print to the user:

```
Handoff written:
- UPDATES.md          (+1 entry)
- <ledger>            (+<N> AD entries)
- NEXT_SESSION.md     (overwritten)

Commit:
  <sha if committed | "skipped (user declined)" | "skipped (--no-commit)" | "no changes">

Verification commands for next session:
  <list>

Resume command:
  /session-catchup
```

That is the entire output. No additional commentary — the artifacts speak for themselves.

## Edge cases

- **No project ledger at all**: Default to creating `DECISIONS.md` in the project root. Report what was created.
- **Multiple candidate ledgers**: First match by the discovery order in the umbrella `SKILL.md`. Report the choice; user can correct on re-run.
- **`--force` with no reason**: Refuse. Force requires a one-line justification that gets prepended to the `UPDATES.md` entry as `> ⚠ Forced wrap: <reason>`.
- **Empty session** (no commits, no edits, no decisions): Skip the handoff write entirely. Print `Nothing to wrap — no state change this session.`
- **Re-run of `/session-wrap` in same session**: Detect by checking if `NEXT_SESSION.md` mtime is within the last 10 minutes AND its content already reflects the current `git rev-parse HEAD`. If so, print `Already wrapped at <time>. No change.` and exit.

## Anti-patterns

- Do **not** summarize the entire conversation into `UPDATES.md`. Five sentences, not fifty.
- Do **not** auto-`git push` or auto-merge. Wrap is a *recording* step, not a *publishing* step.
- Do **not** silently rewrite the ledger summary if this session contradicts a prior decision. Append a new AD that supersedes; the contradiction is the point.
- Do **not** skip phase 1 even when the user is in a hurry. The whole value of `/session-wrap` is the gate.
