# `/session-compact-check` — pre-compaction state persistence

Self-assess whether to compact context window at a task boundary, persisting carry-forward state to project artifacts before any compaction.

Migrated from `~/.claude/commands/compact-check.md` into the session-loop suite so it can share the `NEXT_SESSION.md` / ledger artifact contract with the rest of the pause/resume flows.

## When to invoke

- At a clean task boundary, when context pressure is high.
- User says "compact now", "context is getting heavy", "save state and trim".
- Before starting a large or uncertain next task.

Do not invoke mid-task. The point is to compact only at clean boundaries.

## Procedure

### 1. Assess pressure

- Estimate remaining context budget (rough %).
- Identify whether current context is dominated by completed-task noise (tool outputs, file dumps, dead ends) vs live signal (decisions, open threads, constraints).

### 2. Decide compaction need

Compact ONLY if BOTH true:

(a) >60% of remaining budget consumed, OR next task is large/uncertain.
(b) At a clean task boundary — current task marked done in task metadata, no open sub-threads.

Otherwise skip — proceed to next task.

### 3. Pre-compact persist (mandatory before any compaction)

Write to carry-forward artifacts. Prefer `NEXT_SESSION.md` as the primary destination, since the rest of the session-loop suite already consumes it. If `NEXT_SESSION.md` does not exist in this project, write to the agent's native task metadata.

For `NEXT_SESSION.md` writes via `/session-compact-check`: update only the **"Open threads"** and **"Notes for next session"** sections. Do not overwrite the snapshot or verification commands — those are owned by `/session-wrap` and `/session-checkpoint`. If those sections are missing entirely (no prior wrap/checkpoint), write a minimal `NEXT_SESSION.md` with just open threads and a note `Snapshot pending — run /session-checkpoint or /session-wrap to fill.`

Persist:

- **Completed task**: outcome, key files touched, decisions made, non-obvious gotchas discovered.
- **Carry-forward state**: anything next task depends on that is NOT recoverable by re-reading code/artifacts (e.g. user preferences expressed mid-session, ruled-out approaches with reasons, ambient constraints).
- **Open questions / deferred items**: log to `NEXT_SESSION.md` "Open threads" section. These will also surface in `/session-open-loops`.
- **Reconciliation**: if a canonical state artifact exists (ledger, README, pinned config), diff its top-level summary fields against decisions actually made this session. List divergences explicitly in carry-forward. Do NOT silently rewrite the summary — surface the conflict so the user can ratify (via `/session-decide`).

Verify artifact written before compacting.

### 4. Post-compact rehydrate

First action after compaction: re-read carry-forward artifact (`NEXT_SESSION.md` and/or task metadata) + relevant code files. Do not rely on summarized memory of pre-compact state for anything load-bearing.

### 5. Report

State: `Compacted: yes/no. Reason: <one line>.` then proceed.

## Rule

When uncertain whether context is recoverable from artifacts/code, do NOT compact. Bias toward keeping context.

## Edge cases

- **Decision discovered during reconciliation that wasn't logged**: do not auto-log it. Surface as `Potential AD: <one-line>. Consider /session-decide before compacting.` Let the user decide.
- **No clean boundary** (current task in_progress): refuse to compact. Print `Task in progress — finish or pause it before /session-compact-check.`
- **Project has no `NEXT_SESSION.md`**: fall back to agent's native task metadata. Persist there. Note in output that NEXT_SESSION.md doesn't exist yet (user can run `/session-checkpoint` to bootstrap one).
- **Compaction would lose distinctive context that hasn't been recorded anywhere** (e.g. nuanced user preferences expressed mid-session): refuse to compact until those are persisted. Surface what would be lost.

## Anti-patterns

- Do **not** compact when uncertain. Cost of keeping context = slower next response. Cost of losing context = redoing work, repeating questions, making wrong decisions.
- Do **not** overwrite `NEXT_SESSION.md`'s snapshot / verification commands from compact-check. Those belong to wrap/checkpoint.
- Do **not** log decisions to the ledger from compact-check. Surface the candidate, route to `/session-decide`.
- Do **not** report success without verifying the persist write actually landed.
