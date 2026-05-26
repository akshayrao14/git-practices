---
name: session-loop
description: Multi-day project pause/resume toolkit for agent-assisted work. Provides a coherent set of sub-flows for ending a session safely (`/session-wrap`), rehydrating context at the start of the next session (`/session-catchup`), light mid-session saves (`/session-checkpoint`), reality-vs-ledger drift checks (`/session-drift`), append-only decision logging (`/session-decide`), unresolved-thread scans (`/session-open-loops`), and pre-compaction state persistence (`/session-compact-check`). Operates over a shared artifact contract — `NEXT_SESSION.md` for ephemeral handoff state, `DECISIONS.md` (or an existing ledger) for append-only ADRs, and `UPDATES.md` for dated narrative. Use when the user says "let's stop here", "wrap up", "pick up where we left off", "what was I doing", "before I touch X, check the world", "log this decision", "what's left open", or invokes any of the slash commands above. Designed for projects that span days or weeks where session boundaries are real and context is expensive to rebuild from scratch.
---

# Session Loop

A pause/resume toolkit for multi-day projects worked on with agent assistants (Claude Code, Codex, etc.). Composes with append-only project ledgers — does **not** replace them.

## Why this exists

Multi-day projects fail at the seams. The work itself is fine. The handoffs between sessions are where context evaporates, decisions get re-litigated, and silent drift compounds. This skill is the missing scaffolding around `agent + project + ledger` that makes pause/resume robust.

## Sub-flows

| Slash form | When it fires | Sub-skill file |
| --- | --- | --- |
| `/session-wrap` | End of session. User says "stop for today", "let's wrap up", "I'm done". | [`sub/wrap.md`](sub/wrap.md) |
| `/session-catchup` | Start of session. User says "pick up where we left off", "what was I doing", "resume the migration". | [`sub/catchup.md`](sub/catchup.md) |
| `/session-checkpoint` | Mid-session light save. User says "stepping away for an hour", "save my place". | [`sub/checkpoint.md`](sub/checkpoint.md) |
| `/session-drift` | Sanity check world vs ledger. User says "check the world before I run helm", "is the ledger still accurate". | [`sub/drift.md`](sub/drift.md) |
| `/session-decide` | Log an ADR-style decision. User says "we just decided X, log it", "record this call". | [`sub/decide.md`](sub/decide.md) |
| `/session-open-loops` | Scan unresolved threads. User says "what's still open", "what did we defer". | [`sub/open-loops.md`](sub/open-loops.md) |
| `/session-compact-check` | Pre-compaction state persistence. User says "compact now", or context pressure is high at a task boundary. | [`sub/compact-check.md`](sub/compact-check.md) |

## Shared artifact contract

These files live in the project root. Each sub-flow reads and/or writes a defined subset. The contract is convention — no sub-flow hard-fails if a file is missing, but they are most useful when all three exist.

| File | Lifecycle | Owner sub-flows |
| --- | --- | --- |
| `NEXT_SESSION.md` | Ephemeral. Overwritten on every `/session-wrap` and `/session-checkpoint`. Consumed by `/session-catchup`. | Write: `wrap`, `checkpoint`. Read: `catchup`, `open-loops`. |
| `DECISIONS.md` (or project's existing ledger, e.g. `MIGRATION_LEDGER.md`) | Append-only. Never retro-edit; supersede with new dated entries. | Write: `decide`. Read: `catchup`, `drift`, `open-loops`. |
| `UPDATES.md` | Append-only narrative, newest-on-top, dated. | Write: `wrap`. Read: `catchup`. |

If the project already maintains an external-brain ledger under a different name (e.g. `MIGRATION_LEDGER.md`, `PROJECT_LOG.md`), each sub-flow auto-detects it — see "Ledger discovery" below.

## Ledger discovery

Sub-flows look for an existing append-only ledger in this order:

1. `DECISIONS.md`
2. `MIGRATION_LEDGER.md`
3. `PROJECT_LOG.md`
4. `ADR.md` or `docs/adr/`
5. Any top-level `*.md` whose first 50 lines contain both "append" and ("ledger" OR "ADR" OR "decision")

First match wins. If none found, sub-flows default to writing into `DECISIONS.md`. The chosen path is reported in output, so the user can correct it on the first run.

## Design principles

- **Append-only**: Decisions and narrative are never retro-edited. Supersede with new entries.
- **Idempotent**: Every sub-flow is safe to rerun. `/session-wrap` twice in a row produces one handoff, not two duplicate entries.
- **Verify, don't trust**: Handoffs include commands future-you re-runs to confirm world state. Prose claims are corroborated, not believed.
- **Refuse dirty stops**: `/session-wrap` refuses to write a handoff if the working tree is dirty in dangerous ways (uncommitted secrets, half-applied IaC, orphaned cloud resources). User must clean up or pass `--force`.
- **Surface drift, don't paper over it**: `/session-catchup` and `/session-drift` re-run verification commands. If reality has changed since handoff, the divergence is the first thing reported.
- **Compose with existing conventions**: If the project already has a `MIGRATION_LEDGER.md`, sub-flows append to it rather than creating a parallel `DECISIONS.md`.

## Installation

```bash
npx skills add akshayrao14/session-loop
```

Installs into the right skills dir for your agent (Codex `~/.codex/skills`, Claude Code `~/.claude/skills`, or open-standard `~/.agents/skills`). Restart your agent session afterward.

## Trigger phrases (umbrella)

Any of these route the agent to this skill, which then dispatches to the right sub-flow:

- "Let's wrap up" / "Stop for today" / "End of session" → `/session-wrap`
- "Pick up where we left off" / "What was I doing" / "Resume" → `/session-catchup`
- "Save my place" / "Stepping away" → `/session-checkpoint`
- "Check the world" / "Drift check" / "Is the ledger still accurate" → `/session-drift`
- "Log this decision" / "Record this call" / "Add an ADR" → `/session-decide`
- "What's still open" / "What did we defer" → `/session-open-loops`
- "Compact now" / context pressure at task boundary → `/session-compact-check`

## Dispatch

When this skill activates without a clear slash form, dispatch by intent:

1. If the user is asking to **end** work → load `sub/wrap.md`.
2. If the user is asking to **start** or **resume** work → load `sub/catchup.md`.
3. If the user is asking to **verify** project state → load `sub/drift.md`.
4. If the user is asking to **record** a decision → load `sub/decide.md`.
5. If the user is asking what is **unresolved** → load `sub/open-loops.md`.
6. If the user wants a **light save** (not full wrap) → load `sub/checkpoint.md`.
7. Pre-compaction at a task boundary → load `sub/compact-check.md`.

Each sub-file is self-contained: load only the one that matches.

## Versioning

This skill is published as an umbrella. All sub-flows version together to keep the artifact contract coherent. See [`README.md`](README.md) for the changelog.
