# session-loop

A pause/resume toolkit for multi-day agent-assisted projects (Claude Code, Codex, etc.). Provides a coherent set of slash commands that compose with append-only project ledgers — not a replacement for them.

## Why this exists

Multi-day projects fail at the seams. The work itself is fine. The handoffs between sessions are where context evaporates, decisions get re-litigated, and silent drift compounds.

Existing agent primitives — context compaction, memory, in-session task lists — don't cover the pause/resume seam between sessions. `session-loop` is the missing scaffolding.

## Commands

| Slash form | Purpose |
| --- | --- |
| `/session-wrap` | End-of-session handoff. Safety gate (refuses dirty stops) + handoff write (UPDATES.md, ledger, NEXT_SESSION.md). May auto-commit its own artifacts only. |
| `/session-catchup` | Start-of-session rehydration. Reads handoff, runs drift check, proposes next move. Replaces the built-in `/resume` (which loads chat transcripts, not project state). |
| `/session-checkpoint` | Mid-session light save. For stepping away for an hour, not stopping for the day. |
| `/session-drift` | Reality vs ledger reconcile. Read-only. Re-runs verification commands and probes resources from the last 3 ADs. |
| `/session-decide` | Append an ADR-style decision to the project's ledger. Forces context/decision/alternatives/supersedes/blast-radius/reversibility fields. |
| `/session-open-loops` | Scan unresolved threads across handoff, narrative log, ledger, in-repo TODOs, open PRs, pending tasks. Ranked. Read-only. |
| `/session-compact-check` | Pre-compaction state persistence at a clean task boundary. Migrated from the standalone `/compact-check`. |

All commands also auto-trigger from natural language phrases — `/session-wrap` from "let's stop here", `/session-catchup` from "pick up where we left off", etc.

**New to this? Read [`WALKTHROUGH.md`](WALKTHROUGH.md)** — a concrete day-1, day-2, day-3 walkthrough with sample outputs for every command. The rest of this README is reference; the walkthrough is the on-ramp.

## Artifact contract

`session-loop` writes to three files in the project root. The contract is convention — no command hard-fails if a file is missing, but the suite is most useful when all three exist.

| File | Lifecycle | Owners |
| --- | --- | --- |
| `NEXT_SESSION.md` | Ephemeral. Overwritten by every `/session-wrap` and `/session-checkpoint`. | Write: wrap, checkpoint. Read: catchup, open-loops, compact-check (notes section only). |
| `DECISIONS.md` (or `MIGRATION_LEDGER.md`, `PROJECT_LOG.md`, `docs/adr/`) | Append-only. Never retro-edit; supersede with new dated entries. | Write: decide. Read: catchup, drift, open-loops. |
| `UPDATES.md` | Append-only narrative, newest-on-top, dated. | Write: wrap. Read: catchup, open-loops. |

### Ledger auto-discovery

Commands look for an existing append-only ledger in this order:

1. `DECISIONS.md`
2. `MIGRATION_LEDGER.md`
3. `PROJECT_LOG.md`
4. `ADR.md` or `docs/adr/` (directory)
5. Any top-level `*.md` whose first 50 lines mention "append" and ("ledger" OR "ADR" OR "decision")

First match wins. If none found, defaults to creating `DECISIONS.md` on first `/session-decide` invocation.

This is how `session-loop` composes with projects that already have an external-brain ledger under a different name — no migration needed.

## Install

```bash
npx skills add akshayrao14/session-loop
```

Installs the skill into your agent's skills dir (`~/.claude/skills/`, `~/.codex/skills/`, or `~/.agents/skills/`) and symlinks each slash command stub into the matching commands dir (e.g. `~/.claude/commands/`). Restart your agent session afterward.

### Manual install (from a clone)

```bash
git clone https://github.com/akshayrao14/session-loop ~/session-loop
bash ~/session-loop/install.sh
```

Set `SKILLS_HOME` to override auto-detection (e.g. `SKILLS_HOME=~/.claude/skills bash install.sh`). Set `FORCE=1` to replace stale symlinks (still refuses to overwrite real files).

## Design principles

- **Append-only**: Decisions and narrative are never retro-edited. Supersede with new entries — the historical record stays intact.
- **Idempotent**: Every command is safe to rerun. `/session-wrap` twice in a row produces one handoff, not two duplicate entries.
- **Verify, don't trust**: Handoffs include commands future-you re-runs to confirm world state. Prose claims are corroborated, not believed.
- **Refuse dirty stops**: `/session-wrap` refuses to write a handoff if the working tree is dirty in dangerous ways. User cleans up or passes `--force <reason>`.
- **Surface drift, don't paper over it**: `/session-catchup` and `/session-drift` re-run verification commands. Divergence is the first thing reported.
- **Strict authority boundary**: Commands have full authority over their own artifacts (NEXT_SESSION.md, ledger entries they write, UPDATES.md) — they may write and commit those. They have **suggest-only** authority over user work (source code, infra files) — they never auto-fix, auto-stage, or auto-commit user-owned files.
- **Compose with existing conventions**: If the project already has a `MIGRATION_LEDGER.md`, commands append to it rather than creating a parallel `DECISIONS.md`.

## Typical usage

### Day 1, end of session

```
> /session-wrap
```

Runs safety gate. If anything dangerous is uncommitted (secrets, conflict markers, half-applied IaC), refuses with a list. User cleans up. Re-run:

```
> /session-wrap
```

Writes `UPDATES.md` entry, appends any session decisions to the ledger, overwrites `NEXT_SESSION.md` with snapshot + verification commands + top 3 entry points. Prompts to commit handoff artifacts.

### Day 2, fresh session

```
> /session-catchup
```

Reads `NEXT_SESSION.md`, runs the verification commands from day 1, diffs against current reality. If everything matches: prints summary + recommended next move. If drift: pauses, asks user to acknowledge before proceeding.

### Mid-session, before risky operation

```
> Before I run helm upgrade, /session-drift
```

Probes ledger-claimed resources against actual cluster state. Surfaces concerning divergence.

### Decision made in conversation

```
> We just decided to use Cognito Token Bridge for interim auth. /session-decide
```

Walks through ADR fields (context, decision, alternatives rejected, supersedes, blast radius, reversibility). Appends to ledger.

### Stepping away for lunch

```
> /session-checkpoint
```

Light save. Overwrites `NEXT_SESSION.md` with minimal snapshot. No safety gate, no commit. Flags any irreversible boundary crossed since last save.

### Periodic hygiene

```
> /session-open-loops
```

Ranked list of unresolved threads from every source. Useful before `/session-wrap` to make sure carry-forward is complete.

## Examples that compose with existing ledgers

If your project already has `MIGRATION_LEDGER.md` (append-only, AD-NNN format, supersede-don't-retro-edit), `session-loop` integrates seamlessly:

- `/session-decide` discovers and appends to it.
- `/session-catchup` reads the last 3 ADs.
- `/session-drift` probes the resources named in those ADs' Blast radius fields.
- `/session-wrap` appends new ADs for any in-session decisions and writes its `UPDATES.md` entry in a fresh `UPDATES.md` (separate from the ledger).

No project structure changes required. The ledger's existing conventions stay in charge.

## Beyond engineering

The core ideas — append-only ledger, handoff/rehydrate, drift check, ADR-style decisions, open-loops, idempotency — are domain-agnostic. The current *implementation surface* (probes, gates, examples) is engineering-flavored, but the loop applies to any multi-day work where session boundaries cost you context.

Side-by-side mapping of how each concept translates per domain:

| Concept | Engineering | Product management | Research | Long-form writing |
|---|---|---|---|---|
| **Wrap safety gate** | `git status` clean; no secrets uncommitted; no half-applied Helm/Terraform | Open Notion/Google docs saved; draft Slack/email reviewed; no unposted Loom uploads | Notes synced to repo; recent papers cited; experiment results captured | Draft saved; version tag applied; reviewer comments addressed |
| **Verification command** | `git rev-parse HEAD`, `kubectl get pods`, `terraform plan -detailed-exitcode` | Linear issue state, Slack thread state, last-edit timestamp on key Notion page | Citation graph query, last-pulled-from-arxiv timestamp, dataset checksum | Word count delta, reviewer comment count, last published version diff |
| **Irreversible boundary** | `helm install` succeeded, `terraform apply` succeeded, `gh pr merge`, image pushed | Message sent to exec channel, Linear issue marked Shipped, contract signed, vendor selected | Preprint posted to arXiv, dataset published, IRB filing submitted | Sent to editor, published, retracted/erratum filed |
| **Ledger entry example** | "Use Cognito Token Bridge for interim auth (AD-007). Supersedes manual JWT minting." | "Defer Q3 launch to Q4 after stakeholder review. Supersedes earlier Q3 commit; cause: legal review timeline." | "Drop hypothesis H2 — invalidated by experiment 4 cohort B." | "Cut chapter 7 — pacing review by editor; consolidate into chapter 6 epilogue." |
| **Open-loops source** | In-repo `TODO`/`FIXME`, open PRs, agent task list | Linear issues assigned + mentioned, Slack mentions unread, action items from last meeting notes | Reviewer comments on draft, undelivered experiment runs, papers queued for response | Beta-reader feedback, editor margin notes, unresearched citations |

### How to use today vs how it will get better

The narrative + ledger structure works for any domain right now. PMs, researchers, and writers can productively use `/session-wrap`, `/session-catchup`, `/session-decide`, and `/session-open-loops` — they capture intent, preserve decisions, and re-establish context the same way they do for engineers.

What does **not** work yet for non-engineering domains: the auto-probes inside `/session-wrap`, `/session-drift`, and `/session-checkpoint` look for engineering signals (Helm, Terraform, kubectl, git internals). In a Notion-and-Linear workflow those gates no-op silently and drift checks have nothing to compare against. Outcome: the framework runs but the auto-checks feel empty.

**Workaround today**: in `/session-wrap`, supply your own verification commands manually when prompted (Linear issue queries, Notion last-edit URLs, calendar queries). They land in `NEXT_SESSION.md` and `/session-catchup` will re-run them next session. Same mechanics, different probes.

**Planned (not built)**: a lightweight profile system (`.session-loop-profile` in project root, plus `profiles/<name>.md` per domain) that swaps in domain-specific gate and probe sets at invocation time. Deferred until adoption proves the demand. If you'd use this, open an issue against the mirror repo — it's the signal the design needs.

## Not built-in to Claude Code

For reference — these are not Claude Code primitives:

- `/session-wrap` ≠ built-in `/compact` (which trims context, not session state).
- `/session-catchup` ≠ built-in `/resume` (which loads chat transcripts, not project state).
- The auto-memory system (`MEMORY.md`) explicitly excludes "in-progress work, temporary state" — it stores long-lived facts, not session handoff state. `session-loop` covers the gap.

## License

MIT — see [`LICENSE`](LICENSE).
