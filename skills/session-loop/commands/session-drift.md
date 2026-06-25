---
description: Reality vs ledger reconcile. Re-runs verification commands and probes resources from the last 3 ADs. Surfaces concerning divergence. Read-only. See session-loop skill.
---

Invoke the **session-loop** skill with focus=drift. Load `sub/drift.md` from the skill directory and follow it exactly.

Args (optional):

- `--snapshot` — also write raw probe output to `.session-drift/<timestamp>.txt` for later inspection.

Read-only — never writes to NEXT_SESSION.md, the ledger, or any other artifact. Use before risky operations or when confidence in the ledger is low.
