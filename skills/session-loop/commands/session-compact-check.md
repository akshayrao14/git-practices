---
description: Self-assess whether to compact context window at a task boundary, persisting carry-forward state to NEXT_SESSION.md (or task metadata) before any compaction. See session-loop skill.
---

Invoke the **session-loop** skill with focus=compact-check. Load `sub/compact-check.md` from the skill directory and follow it exactly.

Migrated from the standalone `/compact-check` command. If you have `~/.claude/commands/compact-check.md` from before installing session-loop, both will coexist — remove the standalone one when you've confirmed `/session-compact-check` works.
