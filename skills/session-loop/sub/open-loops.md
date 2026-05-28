# `/session-open-loops` — scan unresolved threads

Aggregate every "still open" thread across the project's artifacts into a single ranked list. Use before `/session-wrap` to make sure nothing important is being left silent, or anytime you want to know "what's still on my plate".

## When to invoke

- Before `/session-wrap` — make sure the wrap's "Open threads" section captures everything.
- During a working session, when feeling lost: "what was I supposed to be doing this week?"
- After `/session-catchup` if the catchup output felt incomplete.
- Periodically as project hygiene — open loops accumulate silently.

## What counts as an open loop

Aggregate from these sources:

1. **`NEXT_SESSION.md`** — `Open threads (carry-forward)`, `Blockers / unanswered questions`, top entry points that weren't picked up.
2. **`UPDATES.md`** — most recent N entries' `Open threads` sections (default N=5).
3. **Ledger (`DECISIONS.md` / `MIGRATION_LEDGER.md` / discovered)** — any AD with `Reversibility: partially-reversible` or `irreversible` whose follow-up wasn't logged in a later AD. Also any AD whose Context references a "phase 2" / "later" / "TODO".
4. **In-repo TODO markers** — `TODO`, `FIXME`, `XXX`, `HACK`, `revisit`, `tech-debt`, dated by commit. Filter to ones either authored by the current user OR explicitly mentioning the current project's scope.
5. **Open PRs assigned to the user** — `gh pr list --author @me --state open` (and `--review-requested @me`).
6. **Issues with the user's label** — `gh issue list --assignee @me --state open` if `gh` available and the project has a recognizable repo.
7. **Agent task list** — any tasks still in `pending` or `in_progress` state.

Each source contributes "threads". Deduplicate threads that appear in multiple sources (same wording, same target) — show once with all sources cited.

## Procedure

### Step 1: enumerate threads from each source

For each source, list its open items. Cap at reasonable limits (don't dump 200 TODO markers; cap at 50 for in-repo markers, keep the most recent).

### Step 2: rank by urgency / blast radius

Use a simple scoring rubric:

| Signal | Weight |
| --- | --- |
| Blocker (named blocker in `NEXT_SESSION.md`) | 10 |
| Names an irreversible AD that lacks follow-up | 8 |
| Open PR awaiting user review | 7 |
| Open PR authored by user with stale CI | 6 |
| Top entry point from prior handoff not yet completed | 5 |
| Open issue assigned to user | 4 |
| Carry-forward thread from prior `UPDATES.md` entry | 3 |
| Pending agent task | 3 |
| TODO marker authored by user, dated >30 days | 2 |
| FIXME / XXX in code | 2 |
| Other TODO markers | 1 |

Sort threads by score descending. Within same score, sort by recency (newer first).

This is a rough rubric — adjust if the user asks. The point is to surface what matters first, not to be precisely correct.

### Step 3: output

```
═══ Open loops — <timestamp> ═══

Sources scanned:
  ✓ NEXT_SESSION.md (handoff from <date>)
  ✓ UPDATES.md (last 5 entries)
  ✓ <ledger> (last N ADs scanned)
  ✓ In-repo TODO markers (<count> found, top 10 shown)
  ✓ gh PRs (assignee=@me, review-requested=@me)
  ✓ Agent tasks (pending + in_progress)

Total open loops: <N>

═══ Top priority ═══

1. [BLOCKER] <one-line>
   Source: NEXT_SESSION.md
   Score: 10

2. [PR REVIEW] <pr title> (#NN)
   gh pr view NN
   Score: 7

3. [AD FOLLOW-UP] AD-007 (Cognito Token Bridge) — phase 2 (Keycloak cutover) not yet logged
   Source: <ledger>
   Score: 8

═══ Medium ═══

4. <one-line>
5. <one-line>
...

═══ Low (FYI) ═══

N. <one-line>
N+1. <one-line>
...

Recommendation:
  Tackle items 1-3 next. Items in "Low" are background — surface them again next /session-open-loops scan.
```

If a thread cites the ledger or `NEXT_SESSION.md`, include the AD-NNN reference inline so the user can jump.

### Step 4: do not write

`/session-open-loops` is read-only — same as `/session-drift`. It does not modify any artifact. If the user wants to close a loop, they do so via:

- `/session-decide` (record a decision that resolves it)
- `/session-wrap` (carry it forward explicitly into the next handoff)
- Doing the work and committing
- Closing the PR/issue manually

## Edge cases

- **No artifacts at all**: print `No sources to scan. /session-open-loops needs at least one of: NEXT_SESSION.md, UPDATES.md, or a ledger.` Exit.
- **Massive TODO count** (thousands of in-repo markers in a large repo): cap aggressively. Default to TODO markers authored by current user in the last 90 days. Print the total count so the user knows the rest exist.
- **`gh` not available**: skip PR/issue sources, note in output.
- **Same thread cited in multiple sources**: list once with all citations.
- **Threads phrased ambiguously** ("revisit later", "TBD", "TODO: rewrite this"): include but mark as low-confidence. The user might want to re-articulate them via `/session-decide`.

## Anti-patterns

- Do **not** auto-close anything. Open loops close when the user resolves them — via decisions, work, or explicit dismissal.
- Do **not** flatten the ranking to a single number with no rationale. Show the score *and* the reason (BLOCKER / PR REVIEW / AD FOLLOW-UP / etc.) so the user can disagree.
- Do **not** dedupe too aggressively. If a thread appears in both `NEXT_SESSION.md` and a `UPDATES.md` entry, that's evidence it's been open for a while — flag the persistence, don't hide it.
- Do **not** include "open loops" that are actually just routine project work. The threshold is "this was deferred or blocked", not "this is on the roadmap".
