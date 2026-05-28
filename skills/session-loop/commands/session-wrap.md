---
description: End-of-session safety gate + handoff write. Refuses dirty stops; writes UPDATES.md, ledger entries, and NEXT_SESSION.md. See session-loop skill.
---

Invoke the **session-loop** skill with focus=wrap. Load `sub/wrap.md` from the skill directory and follow it exactly.

Args (optional):

- `--force <reason>` — override the stop-safety gate. Reason is logged into the handoff.
- `--auto-commit` — skip the commit prompt and commit handoff artifacts immediately.
- `--no-commit` — skip the commit prompt and do not commit (for non-interactive runs).

Acts on the current working directory's project. Reads/writes `NEXT_SESSION.md`, `UPDATES.md`, and the discovered ledger.
