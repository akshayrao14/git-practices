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
4. Regen the lockfile via the PM's lockfile-only install command (see PM table).
5. `git add <manifest> <lockfile> && git rebase --continue`
6. `git push --force-with-lease origin <next-branch>`

Do NOT use `--force` (without lease) — it skips the safety check that aborts if the remote has moved beyond what you fetched.
