# git-practices / socratic-method

Files that make an AI coding agent behave as a Socratic tutor for a junior
engineer, instead of just generating code. Background and a worked example:
see [the gist](#) (link here once published).

## What's in this folder

- `AGENTS.md` — the method itself, in the tool-agnostic format that Codex,
  Cursor, Copilot, and other agents read natively.
- `SKILL.md` — a richer version for Claude Code / Claude Desktop, loaded
  automatically only when it's relevant (see Claude Code's Skills feature).
- `mastery-template.md` — starter file for tracking what you've actually
  learned, so the agent asks fewer questions on topics you've already proven
  you understand, and keeps asking on the ones you haven't.

## Setup

**Claude Code (terminal, or the "Code" tab in the Claude Desktop app — they
share the same CLAUDE.md/Skills mechanism; the Desktop app's separate Chat
and Cowork tabs do not, so this setup doesn't apply there):**
1. Clone this repo somewhere on your machine, e.g. `~/git-practices`. Note
   the **absolute path** of where it actually lands — you'll need the real
   path in the next two steps, not just the example below.
2. Symlink the whole `socratic-method` folder (not just `SKILL.md` on its
   own) into `~/.claude/skills/socratic-method`, so `AGENTS.md` is there too.
   Use the absolute path on the source side — a relative one can silently
   resolve to the wrong place (e.g. to itself) depending on which directory
   you ran the command from:
   ```bash
   ln -s /absolute/path/to/git-practices/socratic-method ~/.claude/skills/socratic-method
   ```
3. Add this to your personal `~/.claude/CLAUDE.md`, again with the real
   absolute path, not the placeholder shown here:
   ```markdown
   @/absolute/path/to/git-practices/socratic-method/AGENTS.md
   ```
4. Copy `mastery-template.md` to `~/.junior-growth/mastery.md` and delete the
   example entry.

**Verify it's actually wired up — don't skip this, each step below only
means something if the one before it passed:**

1. `ls -la ~/.claude/skills/socratic-method/` (note the trailing slash — it
   forces `ls` to follow the symlink and list what's inside). You should see
   `AGENTS.md`, `SKILL.md`, `mastery-template.md`, `README.md`. If you get
   "No such file or directory" or "too many levels of symbolic links," the
   symlink itself is broken — redo step 2 with an absolute path.
2. Start a **fresh** Claude Code session and run `/context`. Confirm your
   `socratic-method/AGENTS.md` file shows under **Memory files** with a
   non-trivial token count (a few thousand, not zero). If it's missing, the
   `@` import in step 3 isn't resolving — check the path is correct and
   absolute.
3. In the same session, run `/skills` and confirm `socratic-method` appears
   in the list. If `AGENTS.md` loaded (step 2 passed) but the skill isn't
   listed here, something's wrong with step 2 specifically, not step 3.
4. Now the actual behavioral test — and be specific, not generic. Don't just
   ask "add a feature that does X" and check whether it asks *anything*
   back; a vague prompt can trigger a *different* skill (a planning or
   brainstorming skill, if you have one installed) that asks its own
   requirements questions and looks similar at a glance, without ever
   engaging this method's actual behavior. Instead, ask for something with a
   real technical decision buried in it — e.g. "add a feature that increments
   a counter every time X happens," which has a genuine race-condition
   question hiding in it. You're looking for the agent to pause specifically
   on *that* technical reasoning (not just an opening "why do you need this"
   question) and to hold off on giving you the answer once it does.
5. If you have another planning/design/brainstorming skill installed, this
   matters even more: confirm the Socratic check happens *alongside* that
   skill's own questions, not instead of them, and specifically on a
   technical decision, not just the requirements-gathering part it was
   already going to do anyway.
6. Finish the task, and check `~/.junior-growth/mastery.md` afterward — you
   should see a new entry for whatever concept came up. If everything else
   above passed but this file never updates, the phase-end save isn't
   happening reliably; worth flagging as a bug rather than assuming it's you.

**Codex CLI:**
1. Clone this repo, e.g. `~/git-practices`.
2. Copy or symlink `AGENTS.md` to `~/.codex/AGENTS.md` (this is Codex's
   global, user-level instructions file — it applies across every project).
3. Copy `mastery-template.md` to `~/.junior-growth/mastery.md` as above.

**Other tools (Cursor, Copilot, Aider, Zed, Windsurf, etc.):** these already
read `AGENTS.md` natively in most cases. Check your tool's docs for where it
expects a *global/user-level* `AGENTS.md` versus a per-project one — this
repo's `AGENTS.md` is written to work at either scope.

**A few things worth knowing before you rely on this:**
- The exact paths above (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, the `@`
  import syntax) match each tool's documented behavior as of when this was
  written, but CLI tools change fast — if something doesn't load, check your
  tool's current docs rather than assuming this guide is wrong.
- On very long sessions, Claude Code's context can get compacted, and
  imported instructions aren't always guaranteed to survive that the same
  way a project-root `CLAUDE.md` does. If the agent seems to have "forgotten"
  the method partway through a long session, that's the likely reason —
  worth a quick re-check rather than assuming it's gone for good.

## A note on the mastery file and privacy

Keep the mastery file local, or in a **private** repo if you need it synced
across machines. It can reveal your own skill gaps and reference real code
you've worked on — never make it public. It's yours, full stop: it's not a
performance-review artifact, and a manager shouldn't be asking to see it.
