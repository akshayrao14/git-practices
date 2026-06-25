# `/session-drift` — reality vs ledger reconcile

Standalone sanity check. Runs anytime, not only at `/session-catchup`. Compares what the project's ledger and handoff *claim* about world state against what is actually true right now.

## When to invoke

- Before a risky operation: "Check the world before I run `helm upgrade`."
- Sporadic confidence check after several days of work: "Is the ledger still accurate?"
- After a known out-of-band event: someone else pushed, a deployment was rolled back manually, a teammate restarted a pod.
- Before `/session-decide` — verify the premise of the decision still holds.

`/session-drift` is intentionally not the same as `/session-catchup`. Catchup is the start-of-session ritual with proposing-next-move on the end. Drift is just the reconcile — no next-move proposal, no handoff reading.

## What it does

1. **Collect claims** from project artifacts.
2. **Probe reality** with the corresponding commands.
3. **Diff** claims vs reality.
4. **Surface** divergences, classified as expected vs concerning.

That is the entire scope. Drift does not fix anything, does not write anything, does not commit anything. It is read-only.

## Procedure

### Step 1: collect claims

Read claims in this order, stopping at first source that yields any:

1. **`NEXT_SESSION.md` verification commands** — if present and ≤14 days old. Each command-plus-output pair is a claim.
2. **Most recent `UPDATES.md` "State at wrap" section** — narrative claims about what is deployed, what is configured, what is running.
3. **Last 3 ADs from the discovered ledger** — for each, the "Blast radius" field names artifacts that should reflect the decision.

If none of these exist: print `No claims to verify — no ledger or handoff present. /session-drift requires at least one artifact to reconcile against.` Exit.

### Step 2: probe reality

For each verification command from step 1: re-run it. Capture output.

For each ledger-derived claim (last 3 ADs): if the AD names a specific resource (`AKS namespace foo`, `helm release bar`, `subscription baz`), probe it directly. Common probes:

| Claim type | Probe command |
| --- | --- |
| Git HEAD or branch | `git rev-parse HEAD`, `git status -sb` |
| Helm release deployed | `helm list -n <ns>` |
| Kubernetes namespace exists | `kubectl get ns <ns>` |
| Kubernetes resource deployed | `kubectl -n <ns> get <kind> <name> -o jsonpath='{.status}'` |
| Azure resource exists | `az resource show --ids <id>` or `az resource list -g <rg>` |
| Cloudflare DNS record | `dig <fqdn>` and compare expected target |
| GitHub PR state | `gh pr view <N> --json state,mergeable` |
| Terraform state | `terraform plan -detailed-exitcode` (exit 2 = drift) |
| Docker image tag pushed | `gh api repos/<o>/<r>/actions/runs?event=push&per_page=1` or registry-specific |

Skip probes whose tools are not installed. List the skipped ones in the output — never silently omit.

### Step 3: classify divergences

For each diff, classify:

- **No divergence** — claim and reality match. Don't list these by default; show count only.
- **Expected drift** — natural change since the claim was recorded:
  - Pod names changed (restart-driven; pod *count* unchanged).
  - Log timestamps newer.
  - `kubectl get` resource versions higher.
  - Git ahead of `origin` by some commits (if user has been working).
- **Concerning drift** — material change requiring user decision:
  - Git HEAD changed *backward* (someone reset).
  - Branch diverged from `origin` (both ahead and behind).
  - Pod count or replica count changed.
  - Helm release status changed (`deployed` → `failed`, `pending-upgrade`, `superseded`).
  - Resource that ledger claims exists is missing (or vice versa).
  - Terraform plan exits with code 2 (drift detected).
  - PR state changed (`open` → `merged` / `closed`).

When unsure, classify as concerning. Bias toward surfacing.

### Step 4: output

Print in this order:

```
═══ Drift check — <timestamp> ═══

Sources consulted:
  ✓ NEXT_SESSION.md (handoff from <date>, N days ago)
  ✓ UPDATES.md (last entry <date>)
  ✓ MIGRATION_LEDGER.md (last 3 ADs: AD-NNN, AD-NNN, AD-NNN)

Probes run: <N>  | matched: <N>  | expected drift: <N>  | concerning: <N>  | skipped (tool missing): <N>

Skipped probes (tool unavailable):
  - <probe>: <missing tool>

Expected drift (informational):
  - <one-line per item>

⚠ Concerning drift:

  <Item 1>
    Claim:    <from ledger / handoff>
    Reality:  <from probe>
    Probe:    `<command>`
    Likely:   <one-line interpretation>
    Action:   <one-line suggested response>

  <Item 2>
    ...

Recommendation:
  <one of:>
  - World matches claims. Safe to proceed.
  - Minor expected drift only — proceed but be aware of <item>.
  - Concerning divergence — DO NOT proceed with risky operations until reconciled. Suggested order: (1) clarify <X> with team, (2) /session-decide if a new decision is needed, (3) re-run /session-drift.
```

### Step 5: do not write

Drift never writes. Not to `NEXT_SESSION.md`, not to the ledger, not anywhere. If the user wants to record a divergence-driven decision, that is `/session-decide`. If they want to update the handoff after reconciling, that is `/session-wrap` or `/session-checkpoint`.

The one exception: if drift is invoked with `--snapshot` flag, write the probe output (without classification) to `.session-drift/<timestamp>.txt` for later inspection. This is opt-in only — not the default.

## Edge cases

- **No probes can run** (no `kubectl`, `az`, `gh`, `helm` installed): print `No probes available — install at least one of the cloud CLIs to run drift checks meaningfully.` Exit without classification.
- **Probe times out**: cap each probe at 30s. On timeout, mark as `inconclusive` (not "concerning") and continue.
- **Auth expired** (`az login` token expired, `gh auth` lapsed, `kubectl` context broken): print the auth error and the specific renewal command. Do not try to refresh auth automatically.
- **Ledger claims unparseable resource ID** (free-text claim like "we deployed it"): skip probing, note as `claim too vague to probe — consider adding explicit resource IDs to future AD blast-radius`.
- **Handoff older than 30 days**: print warning at the top: `Handoff is N days old. Expected drift will be high. Focus on Concerning section.`

## Anti-patterns

- Do **not** try to "fix" the drift by editing ledger or handoff files. Surface only — the user decides.
- Do **not** auto-run `/session-wrap` after drift to "record what's true now". That is a forward decision the user must make.
- Do **not** suppress probes that exit non-zero. Non-zero is often the *interesting* signal (resource missing, auth expired).
- Do **not** chain drift into other sub-flows. Each is invoked deliberately.
