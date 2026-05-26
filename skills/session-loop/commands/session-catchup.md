---
description: Start-of-session rehydration. Reads NEXT_SESSION.md + UPDATES.md tail + last 3 ADs, runs drift check on prior verification commands, proposes next move. See session-loop skill.
---

Invoke the **session-loop** skill with focus=catchup. Load `sub/catchup.md` from the skill directory and follow it exactly.

Args (optional):

- `--focus <thread>` — bias the recommendation toward a specific open thread from the handoff.

Replaces the built-in `/resume` (which loads a chat transcript, not project state). Acts on the current working directory's project.
