---
description: Append ADR-style decision to the project's ledger. Forces context/decision/alternatives/supersedes/blast-radius/reversibility fields. Append-only — never retro-edits. See session-loop skill.
---

Invoke the **session-loop** skill with focus=decide. Load `sub/decide.md` from the skill directory and follow it exactly.

Args (optional):

- `--commit` — auto-commit the ledger after appending (otherwise suggests the commit command only).

Uses the template at `templates/DECISION.md`. Discovered ledger order: `DECISIONS.md` → `MIGRATION_LEDGER.md` → `PROJECT_LOG.md` → `docs/adr/`.
