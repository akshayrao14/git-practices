<!--
DECISION.md — ADR entry template.

Consumed by /session-decide. Append entries (do NOT retro-edit prior ones) to the project's discovered ledger (DECISIONS.md, MIGRATION_LEDGER.md, etc.) OR write a new file under docs/adr/ named ADR-NNN-<slug>.md.

Append-only. If a decision turns out to be wrong, record a new AD with `Supersedes: AD-<prior>`. The prior entry stays verbatim.
-->

## AD-NNN · YYYY-MM-DD · <one-line decision title, verb-phrase>

**Context**: <2–4 sentences. What was the forcing function? What problem or constraint triggered this decision? If this AD supersedes a prior one, mention the prior AD-NNN here and why the prior decision turned out to be insufficient.>

**Decision**: <What was chosen. State affirmatively in one or two sentences. "We will X." Not "We are thinking about X" or "We probably want X".>

**Alternatives rejected**:
- **<Alternative 1>** — <one-line reason it was rejected>
- **<Alternative 2>** — <one-line reason it was rejected>

(If no alternatives were considered: record that explicitly — `**Alternatives rejected**: None considered. Decision made under time pressure / without deliberation.` This is informative for future re-evaluation.)

**Supersedes**: <AD-NNN of the prior decision being superseded, or `None` if this is a fresh decision>

**Blast radius**:
- Services / repos: <list>
- Files: <list, if specific>
- Resources: <cloud resource IDs, helm releases, etc. — be specific, not "stuff in our cluster">
- Teams: <who is affected operationally>

**Reversibility**: <`reversible` | `partially-reversible` | `irreversible`> — <one-sentence explanation. E.g. "Reversible by re-running migration with rollback flag." Or "Irreversible: production data has been deleted under this schema change.">

**Author**: <agent name + version> · <user name if known>

---
