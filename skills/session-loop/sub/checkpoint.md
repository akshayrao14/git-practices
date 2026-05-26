# `/session-checkpoint` — mid-session light save

Quick state save when you need to step away for an hour or two — not stop for the day. Lighter than `/session-wrap`. Skips the safety gate but flags newly-crossed irreversible boundaries.

## When to invoke

- Stepping away for lunch / a meeting / a context switch within the same day.
- A long-running task is paused but not done.
- The session is at a natural pause point but not a natural *stop* point.
- You want a recoverable bookmark in case the agent loses context or crashes.

If you are actually stopping for the day, use `/session-wrap` instead. Checkpoint is the lighter cousin — its handoff is less complete and is meant to be consumed within hours, not days.

## How it differs from `/session-wrap`

| Aspect | `/session-wrap` | `/session-checkpoint` |
| --- | --- | --- |
| Safety gate (refuses on dirty work) | Yes | No (warn only) |
| `UPDATES.md` append | Yes | No |
| Ledger append | Yes (logs decisions) | No |
| `NEXT_SESSION.md` overwrite | Yes | Yes |
| Suggested commit | Yes | No |
| Irreversible-boundary flag | Implicit (logged in ledger) | Explicit (loud warning) |

The mental model: wrap is for handoffs across sessions. Checkpoint is for handoffs across hours within a session.

## Procedure

### Step 1: detect newly-crossed irreversible boundaries since last checkpoint

This is the most important part. Checkpoint's job is to make sure you don't drift past a one-way door without noticing.

Compare current state against the prior `NEXT_SESSION.md` snapshot (if any). Flag if any of these happened **since the last checkpoint or wrap**:

- A cloud resource was *created* (`az create`, `aws create`, `gcloud create`, `kubectl apply` of a new namespaced resource).
- A DNS record was changed.
- A secret was rotated (`az keyvault secret set`, `aws secretsmanager update-secret`, `kubectl create secret`).
- A database migration was run.
- A `helm install` or `helm upgrade` succeeded.
- A `terraform apply` succeeded.
- A PR was merged (`gh pr merge`).
- A package was published / image pushed.

If any boundary crossed: print loudly **before** writing the checkpoint:

```
⚠ Irreversible boundary(ies) crossed since last save:
  - <boundary 1>: <one-line detail>
  - <boundary 2>: <one-line detail>

These are not reversible by /session-catchup or /session-wrap. If you intend to record them as decisions, run /session-decide before stepping away.
```

Do not refuse — the user may have legitimately crossed the boundary on purpose. Just make sure they see it.

### Step 2: collect minimal snapshot

Build a snapshot. Smaller than wrap's — just enough to resume within the day:

- Current git HEAD + branch.
- `git status --porcelain` summary (count of modified/added/deleted files; do not list secrets-bearing filenames in full).
- One-line "what I was doing" — extract from recent agent activity.
- One-line "next step" — extract from recent task list or stated intent.
- Up to 3 verification commands (smaller set than wrap; just the essentials).

### Step 3: overwrite `NEXT_SESSION.md`

Use the same template as wrap, but populate fewer fields. Required:

- Snapshot table (with `Wrap kind: checkpoint`).
- "What I was doing" (2–3 sentences).
- "Where I stopped" (1–2 sentences).
- Top 1 candidate entry point (not 3 — checkpoint is shorter horizon).
- Verification commands (with current outputs).

Skip:

- Top 3 entry points (use top 1 only).
- Open threads section (too heavy for an hour-long pause).
- Recommended start reasoning (just point at entry #1).

### Step 4: do NOT commit

Checkpoint does not commit. Why: an hour later you want to keep working on the same dirty state, and a commit-then-amend dance is friction. The next `/session-wrap` will commit `NEXT_SESSION.md` along with its own artifacts if the user confirms.

Print to user:

```
Checkpoint saved.
  Last action:   <one-line>
  Next step:     <one-line>
  Verify with:   <command 1>; <command 2>

To resume: /session-catchup (or just keep working).
```

## Edge cases

- **No prior `NEXT_SESSION.md`**: this is the first save. Skip boundary detection (no baseline to compare). Just write the file.
- **Prior `NEXT_SESSION.md` is a wrap, not a checkpoint**: that's fine. Treat it as the baseline for boundary detection.
- **Rapid re-checkpointing** (multiple checkpoints within a few minutes): allowed but probably wasteful. After the third one in 10 minutes, print `You've checkpointed 3 times in 10 minutes. Are you actually pausing, or just nervous? Consider /session-wrap if stopping.`
- **Boundary detected but user explains it**: e.g. user says "yes I just rotated that secret, it was intentional". Note their explanation in the "Notes for next session" section of `NEXT_SESSION.md`. Still write the checkpoint.
- **Long gap since last save** (>1 day): warn `Last save was N days ago — checkpoint isn't the right tool for that gap. Consider /session-wrap.`

## Anti-patterns

- Do **not** use checkpoint as a substitute for wrap at end of day. Wrap exists for a reason — the safety gate.
- Do **not** silently overwrite a wrap-kind `NEXT_SESSION.md` with a checkpoint-kind one and lose the wrap's richer fields. If overwriting a wrap, *append* the checkpoint as a sub-section under the wrap, or print warning before overwrite.
- Do **not** log decisions to the ledger from checkpoint. That is `/session-decide`'s job. Checkpoint is narrative-only.
- Do **not** run probes or drift checks. Checkpoint is meant to be cheap and fast. If the user wants to verify state, they invoke `/session-drift` separately.
