<!--
NEXT_SESSION.md — ephemeral handoff state.

Written by /session-wrap or /session-checkpoint. Consumed by /session-catchup. Overwritten (not appended) every time.

This is NOT a long-lived artifact. Do not link to it from other docs. Do not cite it in commits. If something here matters long-term, it belongs in DECISIONS.md (or the project ledger) or UPDATES.md.
-->

# Handoff — <YYYY-MM-DD HH:MM TZ>

## Snapshot

| Field | Value |
| --- | --- |
| Wrap kind | `wrap` or `checkpoint` |
| Project root | `<absolute path>` |
| Branch | `<branch name>` |
| Git HEAD | `<short sha>` (`<full sha>`) |
| Ahead of origin | `<N>` commits |
| Working tree | clean / dirty (see Dirty files below) |
| Forced wrap? | no / yes — reason: `<reason>` |
| Agent / model | `<name + version>` |

## What I was doing

<2–4 sentences. The narrative beat. Not a list of every tool call — the *intent*.>

Example: "Migrating auth-ternity from AWS Lambda (me-central-1) to AKS UAE North. Got the Helm chart rendering cleanly, applied to dev cluster, pods are Running but the readiness probe is flapping. Suspect the JWKS cache initialization is racing with the first request."

## Where I stopped

<2–4 sentences on the exact stopping point. What was the last action taken? What is the immediate next action that would resume work?>

## Top 3 candidate entry points

In priority order. Each is a concrete, small action the next session can start with — not a high-level milestone.

1. **<title>** — <one-line action and expected outcome>
2. **<title>** — <one-line action and expected outcome>
3. **<title>** — <one-line action and expected outcome>

## Recommended start

`#<N>` because `<one-line reason>`.

## Open threads (carry-forward)

Things that are *not* recoverable by reading the code or ledger. Mid-session intent, ruled-out approaches, ambient constraints expressed by the user.

- <thread>
- <thread>

## Blockers / unanswered questions

<Anything that requires human input, an external decision, or a stakeholder ping before progress can resume.>

- <blocker>

## Verification commands

Run these at start of next session (via `/session-catchup`) to confirm the world still matches this snapshot. Each command paired with the output observed at wrap time.

```
$ <command 1>
<output observed at wrap>

$ <command 2>
<output observed at wrap>
```

Minimal recommended set:

```
$ git rev-parse HEAD
<sha>

$ git status --porcelain
<(empty if clean)>
```

Add domain-specific commands as relevant: `kubectl get pods -n <ns>`, `helm list -n <ns>`, `gh pr view <N> --json state,mergeable`, `az resource list --resource-group <rg> -o table`, `terraform plan -detailed-exitcode`.

## Dirty files (if any)

Only populated when `--force` was used. Otherwise the gate would have refused.

```
<git status --porcelain output>
```

## Resume command

```
/session-catchup
```

(Or a specialized variant if the next session has a clear non-default start: `/session-catchup --focus <thread>`.)

## Notes for next session

<Free-form. Anything that doesn't fit the slots above but the next session should know. Keep it short — long notes belong in UPDATES.md, not here.>
