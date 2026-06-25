# `/session-catchup` — start-of-session rehydration

Read the prior session's handoff, verify the world still matches, then propose the next move. Replaces the built-in `/resume` (which loads a chat transcript, not project state).

## When to invoke

- Start of a new session on a multi-day project.
- User says "pick up where we left off", "what was I doing", "resume the migration".
- Fresh shell, fresh worktree, fresh agent — no memory of prior session.

## Procedure

### Step 1: locate handoff

Look for `NEXT_SESSION.md` in the project root. If missing:

- Check git log for a recent commit message mentioning "wrap" or "handoff" — surface it.
- Read the top entry of `UPDATES.md` if present — surface its `Open threads` section.
- Print: `No NEXT_SESSION.md found. Falling back to UPDATES.md tail. Run /session-wrap at the end of next session to enable full rehydrate.`

### Step 2: read and parse

Parse `NEXT_SESSION.md`. Extract:

- Handoff timestamp.
- Git HEAD at wrap.
- Branch name.
- Verification commands.
- Top 3 candidate entry points.
- Blockers / unanswered questions.
- Resume command (if specified beyond `/session-catchup`).

Read the **top entry** of `UPDATES.md` (newest narrative). Read the **last 3 AD entries** from the ledger (`DECISIONS.md` or discovered).

### Step 3: drift check

This is the critical step. Do **not** skip it, even if the user is impatient.

Re-run every verification command from the handoff. For each:

| Command | Wrap output | Now | Match? |
| --- | --- | --- | --- |

If **all match**: print `World matches handoff. Safe to resume.`

If **any differ**: build a divergence table. For each divergence, classify:

- **Expected** — natural drift since handoff (timestamps, log lines, pod restart counts within tolerance).
- **Concerning** — material change (different git HEAD, new resources, branch diverged from origin, pod count changed, deployment status flipped).

For concerning items: list them prominently and **pause**. Do not propose next steps until the user acknowledges or explains the divergence. Examples of how to surface:

```
⚠ Drift detected since wrap (2026-05-25 19:30):

  Git HEAD changed:
    wrap:    abc1234
    now:     def5678
    diff:    `git log abc1234..def5678 --oneline`

  Kubernetes pods changed:
    wrap:    auth-ternity-7f8b9c-x2k4l Running
    now:     auth-ternity-9d2a1b-q7n3m Running
    likely:  pod was restarted or redeployed since wrap

What's the right read here? Was this expected, or did something happen out-of-band?
```

### Step 4: detect worktree identity

Compare current `git rev-parse --show-toplevel` against the handoff's recorded path (if recorded). Detect:

- **Same worktree, same machine**: full continuity. Use the handoff verbatim.
- **Same worktree, different commit**: someone (or you) committed/pulled since wrap. Drift check covers this.
- **Different worktree** (e.g. user re-cloned): warn. Untracked artifacts (`NEXT_SESSION.md`) won't be present in a fresh clone — confirm they were committed or are available some other way.

### Step 5: propose next move

Only after drift is acknowledged. Output format:

```
═══ Catchup summary ═══

Project:       <directory or project name>
Last session:  YYYY-MM-DD (N days ago)
Wrap status:   clean | forced (reason: ...) | no NEXT_SESSION.md

What happened last time:
  <1–3 sentences from UPDATES.md top entry>

Recent decisions (last 3 ADs):
  AD-NNN: <title>
  AD-NNN: <title>
  AD-NNN: <title>

Open threads from handoff:
  - <thread 1>
  - <thread 2>

World state:
  ✓ All verification commands match handoff
  (or: drift table from step 3)

Candidate entry points (from handoff, in priority order):
  1. <entry 1>
  2. <entry 2>
  3. <entry 3>

Recommend starting with #<N> because <reason>.
What would you like to tackle first?
```

Pick the recommendation from the handoff's stated top entry point. If drift was detected, the recommendation may shift — say so explicitly.

## Edge cases

- **NEXT_SESSION.md older than 14 days**: Print `Handoff is N days old. Worth a /session-drift pass before trusting it.` and run `/session-drift` semantics inline (a fuller reality-vs-ledger reconcile, not just the verification commands).
- **NEXT_SESSION.md exists but is empty or malformed**: Fall back to `UPDATES.md` tail. Print warning.
- **No ledger, no UPDATES, no NEXT_SESSION**: This is a first session, not a catchup. Print `No prior session state found. This is a fresh start.` Don't run drift check.
- **`--force` used at last wrap**: Surface the forced-wrap reason prominently. Forced wraps often hide unfinished business.
- **Verification commands fail to run** (tool missing, auth expired): Don't silently skip. Print `Could not verify <command>: <error>. Resolve before relying on handoff.`

## Anti-patterns

- Do **not** start work before the drift check completes. The whole point is to catch drift *before* it compounds.
- Do **not** treat the handoff as ground truth. The handoff is a *claim* about world state at the time of wrap. The verification commands corroborate it.
- Do **not** silently update `NEXT_SESSION.md`. It is overwritten only by `/session-wrap` or `/session-checkpoint`, never by `/session-catchup`.
- Do **not** dump the entire ledger or full `UPDATES.md` into the catchup output. Last entry + last 3 ADs is enough. The user can ask for more.
