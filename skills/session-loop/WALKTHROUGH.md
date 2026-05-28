# Walkthrough — first three sessions

Concrete day-by-day example of how `session-loop` actually feels in practice. Sample outputs are illustrative — your project's outputs will differ in detail but the shape stays the same.

## Prerequisites

- `session-loop` installed (`npx skills add akshayrao14/session-loop` or run `install.sh` from a local clone).
- Agent session restarted after install — confirm with `/help` or by typing `/session-` and seeing the seven commands in autocomplete.
- A real multi-day project. Solo tasks under a day get no value from this; the cost of the wrap/catchup ritual exceeds the benefit until cold-start cost actually hurts.

The walkthrough uses an engineering example (a service migration). The same shape works for non-engineering multi-day work — see the **Beyond engineering** section in [`README.md`](README.md) for the mapping.

## Session 1 — bootstrap

Scenario: spent four hours on day one of an AWS-to-Azure migration. Got the Helm chart rendering cleanly, applied to dev cluster, pods are running but the readiness probe is flapping. Time to stop.

### You type

```
let's wrap up for today
```

### What the agent does

Recognizes the intent, loads `sub/wrap.md`, runs Phase 1 (safety gate) first.

```
═══ /session-wrap — Phase 1 (stop-safety gate) ═══

| Gate                          | Status | Detail                                  |
|-------------------------------|--------|-----------------------------------------|
| Git working tree              | WARN   | 3 files modified, 1 untracked           |
| Sensitive uncommitted files   | PASS   |                                         |
| Branch ahead of origin        | WARN   | 2 commits ahead — consider pushing      |
| IaC drift (terraform/helm)    | PASS   |                                         |
| Cloud resources this session  | INFO   | 2 created (aks-uaen-dev, helm release)  |
| Open agent tasks              | PASS   |                                         |
| Conflict markers              | PASS   |                                         |

Result: WARN only. No hard fails. Proceed to Phase 2?
```

You confirm. If a FAIL had appeared (e.g. `.env.local` was unstaged), the agent would stop and list the fix — never auto-`git add` for you.

### Phase 2 — handoff write

```
═══ /session-wrap — Phase 2 (handoff write) ═══

1. Ledger discovery: found MIGRATION_LEDGER.md in project root.
2. Captured verification commands:
     - git rev-parse HEAD → 7a3c9f2
     - git status --porcelain → 3 modified, 1 untracked
     - kubectl -n auth-dev get pods → 1 Running (readiness flapping)
     - helm list -n auth-dev → auth-ternity-0.1.0 deployed
3. Wrote new entry to UPDATES.md (top).
4. Logged 1 decision to MIGRATION_LEDGER.md as AD-008
   (chose probe-period 30s after initial 10s caused thrash).
5. Wrote NEXT_SESSION.md (overwrote prior).

Handoff written:
  - UPDATES.md          (+1 entry)
  - MIGRATION_LEDGER.md (+1 AD entry: AD-008)
  - NEXT_SESSION.md     (overwritten)

Commit handoff artifacts? [y/N]
```

You answer `y`. Agent runs:

```bash
git add UPDATES.md MIGRATION_LEDGER.md NEXT_SESSION.md
git commit -m "chore(session): wrap 2026-05-25"
```

Final output:

```
Commit:
  abc123e chore(session): wrap 2026-05-25

Resume command:
  /session-catchup
```

### What `NEXT_SESSION.md` looks like now

(Abridged — see `templates/NEXT_SESSION.md` for full structure.)

```markdown
# Handoff — 2026-05-25 17:42 UTC

## Snapshot

| Field          | Value                                       |
| -------------- | ------------------------------------------- |
| Wrap kind      | wrap                                        |
| Branch         | feat/auth-ternity-aks                       |
| Git HEAD       | 7a3c9f2                                     |
| Ahead of origin| 2 commits                                   |
| Working tree   | dirty (3 modified, 1 untracked)             |

## What I was doing

Migrating auth-ternity from AWS Lambda (me-central-1) to AKS UAE North.
Got the Helm chart rendering cleanly, applied to dev cluster, pods are
Running but the readiness probe is flapping. Suspect the JWKS cache
initialization is racing with the first request.

## Where I stopped

After bumping initialDelaySeconds from 10 to 30. Pod stabilized but
the third pod hasn't passed readiness in 4 minutes — likely a different
root cause than the cache race.

## Top 3 candidate entry points

1. **Diagnose pod-3 readiness** — `kubectl describe pod auth-ternity-xxx -n auth-dev`, look at probe events for the specific failure mode
2. **JWKS cache instrumentation** — add a log line at cache init to confirm/deny the race hypothesis
3. **Cloudflare → Azure DNS delegation for dev.uae.tern-group.com** — separate AD-007 thread, also waiting

## Recommended start

#1 because pod-3 is the only blocker for the dev deploy completing.

## Verification commands

$ git rev-parse HEAD
7a3c9f2

$ kubectl -n auth-dev get pods
NAME                            READY   STATUS    RESTARTS
auth-ternity-7f8b9c-x2k4l       1/1     Running   0
auth-ternity-7f8b9c-q3n5p       1/1     Running   0
auth-ternity-7f8b9c-r8m1z       0/1     Running   0

$ helm list -n auth-dev
NAME             STATUS     CHART
auth-ternity     deployed   auth-ternity-0.1.0
```

You log off.

## Session 2 — catchup next morning

You come back. Fresh shell. Agent session restarted (or new conversation).

### You type

```
pick up where we left off
```

### What the agent does

Loads `sub/catchup.md`. Reads `NEXT_SESSION.md`, last `UPDATES.md` entry, last three ADs from `MIGRATION_LEDGER.md`. Re-runs the verification commands.

```
═══ /session-catchup — drift check ═══

Re-running verification commands from 2026-05-25 17:42 UTC (15h ago):

| Command                              | Wrap output           | Now                    | Match? |
|--------------------------------------|-----------------------|------------------------|--------|
| git rev-parse HEAD                   | 7a3c9f2               | 7a3c9f2                | ✓      |
| git status --porcelain               | 3 modified, 1 untrack | 3 modified, 1 untrack  | ✓      |
| kubectl -n auth-dev get pods         | 1 Running, 1 flapping | 2 Running, 1 Pending   | DIFFER |
| helm list -n auth-dev                | auth-ternity 0.1.0    | auth-ternity 0.1.0     | ✓      |

⚠ Drift detected:

  Kubernetes pods changed:
    wrap:    auth-ternity-7f8b9c-r8m1z Running (readiness flapping)
    now:     auth-ternity-7f8b9c-r8m1z Pending — ImagePullBackOff (15h)
    likely:  registry credential rotated overnight, or image was retagged

What's the right read here? Was this expected?
```

You investigate the pod, find the ACR pull secret expired, refresh it. Re-run `/session-catchup` (idempotent).

```
═══ Catchup summary ═══

Project:       tern-infra (auth-ternity migration)
Last session:  2026-05-25 (16h ago)
Wrap status:   clean

What happened last time:
  Helm chart applied to dev cluster. 2 of 3 pods Running. Bumped
  readiness initialDelaySeconds from 10 to 30. Pod-3 still failing
  readiness for a different reason than the cache race.

Recent decisions (last 3 ADs):
  AD-006: Use Azure Service Bus for queues + Event Grid for events
  AD-007: Cloudflare → Azure DNS via NS delegation (no Front Door in dev)
  AD-008: readiness initialDelaySeconds 30s (was 10s — caused thrash)

Open threads from handoff:
  - Diagnose pod-3 readiness failure (top priority)
  - JWKS cache instrumentation (hypothesis test)
  - DNS delegation for dev.uae.tern-group.com (waiting)

World state:
  ✓ All verification commands match handoff
  (post ACR creds refresh)

Candidate entry points:
  1. Diagnose pod-3 readiness — `kubectl describe pod ...`
  2. JWKS cache instrumentation
  3. DNS delegation

Recommend starting with #1 because pod-3 is the only blocker for dev deploy.

What would you like to tackle first?
```

You start with #1.

## Session 3 — mid-session patterns

Throughout session 3 you use the supporting commands as needed.

### Drift check before a risky operation

You're about to run `helm upgrade`. Before doing so:

```
before I run helm upgrade, drift check
```

`/session-drift` re-runs the verification commands and probes resources named in recent ADs (`Blast radius` fields). Read-only. If anything changed since `/session-catchup` ran, it surfaces here. Crucial because changes between catchup and now might invalidate your assumptions.

### Logging a decision in conversation

Mid-session you decide:

> Actually, let's use the static JWKS file we already have rather than fetching at boot. Network call at init was probably the race cause.

You realize this is an AD-worthy decision and say:

```
log that as a decision
```

`/session-decide` walks you through the required fields (context, decision, alternatives rejected, supersedes, blast radius, reversibility). The context section explicitly mentions superseding AD-008 (the initialDelaySeconds tweak — turns out the root cause was different). Appends `AD-009` to `MIGRATION_LEDGER.md`. Does **not** retro-edit AD-008 — AD-008 stays verbatim, AD-009 supersedes it.

### Stepping away for an hour

You have a meeting. Not stopping for the day, just pausing.

```
/session-checkpoint
```

Lighter than wrap. No safety gate. Overwrites `NEXT_SESSION.md` with a minimal snapshot:
- One sentence about what you were doing.
- One next step.
- Two verification commands.

Also flags: "since last save, you committed AD-009 (irreversible: ledger appended). Acknowledge?" You confirm.

### Periodic hygiene

Late in the day, before your next wrap:

```
what's still open
```

`/session-open-loops` aggregates from `NEXT_SESSION.md`, `UPDATES.md`, ledger ADs without follow-up, in-repo TODOs, open PRs, and pending agent tasks. Ranks them:

```
═══ Open loops ═══

Top priority:
  1. [BLOCKER] DNS delegation for dev.uae.tern-group.com (carry-forward, AD-007)
  2. [PR REVIEW] auth-ternity #142 (assigned to you, CI passing)
  3. [AD FOLLOW-UP] AD-009 supersedes AD-008 — pod-3 should be retested

Medium:
  4. JWKS cache instrumentation — completed by AD-009? Verify or close.
  5. TODO in helm/templates/deployment.yaml line 47: "revisit resource requests"

Low:
  6-12. ...
```

Item #4 prompts you to check whether the instrumentation thread is now moot (AD-009 made it irrelevant). It is — you close that thread in your head before wrap.

### End of session 3

You wrap again. AD-009 is already in the ledger from earlier. The wrap notes that item #4 was resolved, item #3 (pod-3 retest) is the new top entry point for session 4.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent didn't auto-trigger `/session-wrap` on "let's stop" | Phrase didn't match SKILL.md description | Type `/session-wrap` explicitly. Optionally edit SKILL.md to add your phrasing. |
| Ledger discovery picked the wrong file | Multiple candidates in project root | First-run output names the chosen ledger. Rename or move the wrong candidate, re-invoke. |
| `NEXT_SESSION.md` is in `.gitignore` | Some teams prefer the handoff untracked | Wrap detects this and prints `NEXT_SESSION.md is gitignored — leaving uncommitted`. UPDATES + ledger still committed. |
| Drift check says "auth expired" | `az`/`gh`/`kubectl` token timed out | Refresh per the printed command (`az login`, `gh auth refresh`, etc.). Re-run `/session-drift`. |
| Catchup says "handoff is N days old, run /session-drift" | Long gap since last wrap | Run the suggested `/session-drift` first. Expect more drift; focus on the Concerning section. |
| `/session-wrap` refuses, FAIL on sensitive files | `.env*`, `*.key`, `*.pem` are uncommitted | Commit them deliberately (if they belong in git) or `.gitignore` them. Don't `--force` past this — it's the highest-value gate. |
| Wrap appended AD-NNN but you change your mind | Append-only ledger; no delete | Write a new AD that supersedes. Prior AD stays verbatim. The history matters more than the apparent contradiction. |

## When NOT to use

`session-loop` overhead pays off only when the cost of cold-starting a session is real. Skip it for:

- **Solo tasks under a day.** No handoff needed.
- **Throwaway exploration.** State that won't matter tomorrow.
- **Pair-programming sessions** where another human is the carry-forward.
- **Bug-fix sprints** where nothing accumulates between sessions — each bug is independent.
- **Tasks where you only run agents for short bursts** and never close the chat.

A reasonable threshold: invoke session-loop when at least *two* of these are true: project will span >3 days, multiple decisions accumulate, infrastructure or external state is mutated, sessions cross calendar days, multiple agents/humans collaborate asynchronously.

## What success looks like after a week

- `MIGRATION_LEDGER.md` (or your project's ledger) has 5–10 new AD entries with `Supersedes` chains where decisions evolved.
- `UPDATES.md` has 4–7 dated entries with clear narrative.
- `NEXT_SESSION.md` is overwritten cleanly between sessions — never stale.
- `/session-catchup` consistently re-establishes context in under 30 seconds of agent output.
- `/session-drift` catches at least one out-of-band change you would otherwise have missed (someone pulled, infra rolled back, secret rotated).
- You never feel the "wait what was I doing" tax at the start of a session.

If you're not seeing those after a week, something is off — usually:

- `/session-wrap` is being skipped on rushed end-of-day stops.
- Decisions are happening in conversation but `/session-decide` isn't being invoked.
- The ledger auto-discovered the wrong file (check the wrap output's first lines).
