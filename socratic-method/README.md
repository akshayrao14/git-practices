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
1. Clone this repo somewhere on your machine, e.g. `~/git-practices`.
2. Symlink the whole `socratic-method` folder (not just `SKILL.md` on its
   own) into `~/.claude/skills/socratic-method`, so `AGENTS.md` is there too:
   ```bash
   ln -s ~/git-practices/socratic-method ~/.claude/skills/socratic-method
   ```
3. Add this to your personal `~/.claude/CLAUDE.md`:
   ```markdown
   @~/git-practices/socratic-method/AGENTS.md
   ```
4. Copy `mastery-template.md` to `~/.junior-growth/mastery.md` and delete the
   example entry.
5. **Check it worked:** start a fresh session and ask a non-trivial question
   (e.g. "add a feature that does X"). If the agent doesn't ask you anything
   back before writing code, the import didn't take — re-check step 3 and
   run `/context` in Claude Code to see what actually loaded.

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
you've worked on — never make it public.
