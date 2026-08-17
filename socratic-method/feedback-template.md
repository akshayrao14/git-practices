# Beta feedback log

This is a beta test of the Socratic Method skill. Copy this file to
`~/.junior-growth/feedback.md` (same folder as your mastery file). Like the
mastery file, it's yours — it stays local on your machine, nobody sees it
automatically, and you decide what (if anything) you share and with whom.
Being honest here, including "this was annoying," doesn't reflect on you —
that's exactly the signal that's useful right now.

The agent will occasionally ask one quick, skippable reaction question after
a Socratic exchange and log it here in the format below. You don't need to
fill this in yourself, and you're never obligated to answer if you'd rather
just keep working — an unanswered prompt should just not produce an entry.

## Entry format

```markdown
## 2026-08-17 — Design review — DDB race condition
- Reaction: helpful          (options: helpful / neutral / annoying / skip)
- Note: caught a real bug I would've missed. Felt worth the pause.
```

Delete the two example entries below once you have real ones.

## What's especially useful to flag, beyond the automatic entries

- Whether any of these actually happened for you at all — most of this
  method has only ever been tested by the person who built it, on one kind
  of task: **reviewing a peer's PR, postmortem debugging, estimation**, and
  the **live-incident override** (does it correctly stay quiet while
  something's actually down, and only ask questions in the postmortem after?).
- Any time the override phrase ("skip this, I'm on call" or similar) didn't
  work — i.e. it kept asking anyway.
- Any time it asked about something you'd already been checked on before, as
  if it forgot — or the opposite: it stopped asking about something you
  don't actually feel solid on yet.
- Any time it felt like busywork rather than genuinely useful — be blunt,
  that's exactly the failure mode this is trying to catch early.
- Any setup step that didn't work as written.

## Example entries

## 2026-08-14 — Development — Race condition (login counter)
- Reaction: helpful
- Note: needed the hint ladder, but got there and it stuck.

## 2026-08-15 — Design review — Code entropy
- Reaction: neutral
- Note: fine, but felt like it was testing me more than helping the design
  move forward. Not annoying, just neutral.
