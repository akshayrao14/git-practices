# `/session-decide` — append ADR-style decision

Capture a decision made in conversation as a structured, append-only entry in the project's ledger. Forces the user to articulate the *why* and the *what-was-rejected* so future-them (or a teammate) can re-evaluate the decision later without re-litigating from scratch.

## When to invoke

- User explicitly says "log this", "record this decision", "add an ADR".
- A non-trivial choice was just made in conversation and is at risk of being forgotten or revisited:
  - Choosing one architecture over another.
  - Picking a tool/library/region/SKU.
  - Setting a scope boundary ("only X migrates, not Y").
  - Locking in a workflow contract ("we always do X before Y").
- A decision *supersedes* a prior decision and the prior one is in the ledger — record the supersession explicitly.

If the user is just thinking out loud, do not invoke. Decisions worth logging are ones the user has *committed to* and that have a non-trivial blast radius.

## Procedure

### Step 1: ledger discovery

Find the project's append-only ledger using the discovery order from the umbrella `SKILL.md`:

1. `DECISIONS.md`
2. `MIGRATION_LEDGER.md`
3. `PROJECT_LOG.md`
4. `ADR.md` or `docs/adr/` (if a directory, write a new file `docs/adr/ADR-NNN-<slug>.md` instead of appending to a single file)
5. Heuristic match (any top-level `*.md` whose first 50 lines mention "append" and "ledger"/"ADR"/"decision")

If none found: default to `DECISIONS.md` in project root. Create the file with a one-line header:

```markdown
# Decisions

Append-only ADR log. Never retro-edit; supersede with new dated entries.
```

Print which ledger was chosen so the user can correct on the first run.

### Step 2: collect required fields

Use the template at `templates/DECISION.md`. Required fields, in order:

1. **AD number** — sequential. Find the last `AD-NNN` in the existing ledger; this one is NNN+1. If first decision, `AD-001`.
2. **Date** — today's date in `YYYY-MM-DD`.
3. **Title** — one-line. Verb phrase. ("Use Cognito Token Bridge for interim auth", not "Auth strategy".)
4. **Context** — what triggered this decision? 2–4 sentences. The forcing function.
5. **Decision** — what was chosen. State affirmatively.
6. **Alternatives rejected** — at least one. For each: name + one-line reason it was rejected. If "no alternatives considered", record that too — future-you will want to know.
7. **Supersedes** — prior AD-NNN if any. "None" if this is a fresh decision.
8. **Blast radius** — services, files, resources, teams affected.
9. **Reversibility** — `reversible` / `partially-reversible` / `irreversible`. One sentence on why.
10. **Author** — agent name + user name if known.

If the user has provided some of these in conversation already, fill them in. For missing required fields, ask the user — one question per field, not a wall of questions:

```
What's the forcing function for this decision? (Context — 2-4 sentences)
```

Don't proceed to append until all required fields are filled. The point of `/session-decide` is to extract the information the user is about to forget.

### Step 3: append to ledger

For a single-file ledger: append at the **bottom**. Append-only ledgers grow chronologically; do not insert at the top. (This is different from `UPDATES.md` which is newest-on-top.)

For an `adr/` directory: create a new file `ADR-NNN-<slug>.md`.

Use exactly the template at `templates/DECISION.md`. Do not invent fields. Do not omit fields.

### Step 4: cross-link if superseding

If `Supersedes: AD-<prior>`: do **NOT** edit the prior AD. Append-only means append-only. Instead, in the new AD's `Context` section, mention the supersession explicitly so the reader of the prior AD who searches for its ID finds the new one:

```markdown
**Context**: AD-007 is being superseded. The original decision to use X
turned out to be wrong because Y. This AD records the new choice.
```

A future reader of AD-007 will not see a backlink (impossible without retro-edit). They have two ways to find AD-NNN:

- Read forward chronologically.
- Search the ledger for `Supersedes: AD-007`.

This is acceptable — append-only purity is worth the modest search cost.

### Step 5: confirm

Print to user:

```
Decision recorded:
  AD-NNN · YYYY-MM-DD · <title>
  Ledger: <path>
  Supersedes: <AD-NNN or "none">

Consider committing: git add <ledger>; git commit -m "decide: AD-NNN <title>"
```

`/session-decide` does **not** auto-commit. (Different from `/session-wrap`, which may auto-commit its own artifacts.) Reason: decisions often happen mid-task while user-owned files are dirty. Auto-committing the ledger while user code is half-written creates a commit graph that interleaves decision-log commits with code commits in a confusing way. Suggest the commit; let the user decide when to run it.

If the user wants auto-commit: pass `--commit` flag. With `--commit`, run only `git add <ledger-path>` and `git commit -m "decide: AD-NNN <title>"` — explicit path, no `git add .`.

## Edge cases

- **Multiple decisions in one conversation**: process one at a time. Each gets its own AD number, its own `/session-decide` invocation. Don't bundle.
- **User describes the decision but it's not actually final** ("I'm thinking we should..."): do not log. Ask `Is this a finalized decision, or still under consideration? Decisions in the ledger should be ones you're committing to.`
- **Decision contradicts ledger but isn't framed as supersession**: surface the contradiction. `AD-007 says X. This new decision implies Y, which contradicts. Should this be recorded as 'Supersedes: AD-007'?`
- **AD numbering collision** (two agents racing on the same ledger): re-read the ledger immediately before append; recompute next AD number. If race detected (someone else appended AD-NNN between read and write), retry with NNN+1.
- **No ledger directory exists yet** and project uses `docs/adr/` style: create the directory before the first file write.
- **User wants to delete an AD**: refuse. Append-only. If the decision was wrong, the user records a new AD that supersedes it. The wrong one stays as historical record. Print `Append-only ledgers don't support deletion. Record a new AD that supersedes AD-NNN instead.`

## Anti-patterns

- Do **not** edit prior ADs. Ever. The whole value of append-only is that the historical record is intact.
- Do **not** log every micro-decision. ADs are for choices with non-trivial blast radius. Function-naming, variable choices, formatting preferences — those are not ADs.
- Do **not** bundle multiple decisions into one AD. One decision per AD, even if they were made in the same conversation. Future search benefits from atomic entries.
- Do **not** skip the "alternatives rejected" field. Even "no alternatives considered" is informative — it tells future-you that the decision was reached without deliberation, which may be a reason to re-evaluate.
