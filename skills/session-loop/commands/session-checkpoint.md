---
description: Mid-session light save. Overwrites NEXT_SESSION.md with a minimal snapshot. Flags newly-crossed irreversible boundaries since last save. See session-loop skill.
---

Invoke the **session-loop** skill with focus=checkpoint. Load `sub/checkpoint.md` from the skill directory and follow it exactly.

Lighter than `/session-wrap`. Use when stepping away for an hour or two, not stopping for the day. Does not append to UPDATES.md, does not append to ledger, does not commit.
