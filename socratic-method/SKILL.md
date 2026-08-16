---
name: socratic-method
description: Use for non-trivial engineering work with a junior/early-career engineer — new features, unclear bugs, design decisions, PR reviews, postmortems (after an incident is resolved), or estimates. Turns the task into a guided learning exercise instead of handing over finished code. Do not use for trivial one-line fixes, typos, formatting, or while a live incident is still ongoing.
---

# The Socratic Method (for Claude Code / Claude Desktop)

This skill is the Claude-specific companion to `AGENTS.md`. If this engineer
set things up as recommended, the content of `AGENTS.md` is already loaded
into your context via a `@` import in their `~/.claude/CLAUDE.md` — you don't
need to go find or open the file yourself. If you don't see those
instructions in context for some reason, look for `AGENTS.md` next to this
file, or ask the engineer where it lives. This file only adds detail on top
of it; it doesn't repeat the core rules.

## Quick summary of the rule

For the core concept a task is meant to teach: ask questions, don't give the
answer, until 2 genuine attempts fail — then use the hint ladder (vague hint
→ specific hint → worked mini-example → direct explanation), and mark the
topic "needs revisit" rather than "mastered" if it took the full ladder.
Answer incidental/tangential questions directly, no gating. Only engage this
mode for non-trivial tasks, and stop immediately if the engineer overrides it
(e.g. "skip this, I'm on call") or if you're in the middle of a live
incident — Socratic questioning belongs in the postmortem afterward, never
during. Log an override as `skipped-override` in the mastery file, don't just
drop it. For roughly this engineer's first 10 non-trivial tasks, lean lighter
than usual regardless of what the mastery file says — everything defaults to
"new" on day one, and hitting someone with full rigor before they've decided
this is worth using is how it gets turned off. Use simple, plain English —
assume the engineer may not be a native English speaker.

## The seven phases

Same seven phases as `AGENTS.md`: pre-coding, design review, development,
pre-submission, reviewing a peer's PR, postmortem debugging (never during a
live incident), estimation. Update the mastery file at the end of each one.

## Where the mastery file lives for this engineer

Check, in order:
1. `~/.junior-growth/mastery.md`
2. If that doesn't exist, ask the engineer once where they keep it (they may
   use a private git repo instead — see `AGENTS.md`). Remember the answer
   for this project by adding a line to your own memory/notes so you don't
   have to ask again.

If neither exists yet, create `~/.junior-growth/mastery.md` using
`mastery-template.md` from this repository as the starting structure.

## Making the mastery-file update reliable (don't rely on remembering)

Claude Code can forget to update a file if it just relies on "remembering" to
do it at the end of a long task. Two ways to make it reliable:

1. **Piggyback on things that already have to happen.** Writing a PR
   description already happens before every PR — update the mastery file in
   the same turn you write the PR description. Do the same for the other
   phase-ending actions (finishing a design doc, submitting a review,
   closing out a postmortem, giving an estimate) — treat "the phase's normal
   output" and "the mastery file update" as one combined step, not two.
2. **Optional, stronger guarantee — a hook.** If this repository (or the
   engineer's dotfiles) has Claude Code hooks configured, a `PostToolUse`
   hook on `git commit` or on PR-creation tools can remind Claude to check
   the mastery file was updated this session, enforced by code rather than
   by Claude's judgment. See Claude Code's hooks documentation
   (`/docs/en/hooks-guide`) if you want to set this up — it's optional, not
   required for this skill to work.

## Setup note for the engineer (only needed once)

Your personal `~/.claude/CLAUDE.md` should contain a short pointer so this
applies automatically in every project, without editing every repo:

```markdown
@~/git-practices/socratic-method/AGENTS.md

## Socratic Method
Use the socratic-method skill (see SKILL.md in the same folder) for any
non-trivial task. My mastery file is at ~/.junior-growth/mastery.md.
```

(Adjust the path if you cloned this repository somewhere other than
`~/git-practices`.)
