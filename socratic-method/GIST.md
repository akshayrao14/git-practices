# The Socratic Method for Junior Engineers: Making Your AI Agent Teach, Not Just Type

*A follow-up to my earlier gist, which described a `deep-understanding`
framework for interns pairing with AI coding assistants (share the problem
before code, verify understanding as you go, stress-test the design before
submitting). This one extends the idea to junior engineers, adds Socratic
questioning as the core technique, and — the main upgrade — is built to work
automatically, without re-explaining it to every new chat.*

## The problem

AI coding tools are very good at writing code fast. That's the problem.

A junior engineer can now ship a feature without fully understanding it. The
code works, tests pass, the PR gets merged. But if a bug shows up later, or a
teammate asks "why did you do it this way," the junior may not have a good
answer — because the AI wrote the reasoning too, and the junior only read it,
not built it.

This isn't a guess. Addy Osmani (Head of Engineering at Google) calls this
**cognitive surrender** — accepting AI output without forming your own
understanding, versus **cognitive offloading**, where you use the AI as a
tool but keep your own judgment ([Cognitive Surrender](https://addyosmani.com/blog/cognitive-surrender/)).
Separately, a large 2024 study of 153 million lines of code by GitClear found
copy-pasted code rising and refactoring falling over the same period AI
coding tools spread — a correlation, not proof that AI wrote the duplicated
code, but consistent with the same pattern: code getting patched rather than
understood
([Coding on Copilot](https://www.gitclear.com/coding_on_copilot_data_shows_ais_downward_pressure_on_code_quality)).

The fix isn't "don't use AI." It's changing *how* you use it — so the AI
teaches while it helps, instead of just handing over answers.

## The method: ask before you tell

The core idea is old: the **Socratic method** — a teacher who asks questions
instead of giving answers, so the student has to think it through themselves.
Applied to an AI coding agent, this means one simple rule:

> For anything the task is actually meant to teach, the agent asks a question
> first. It does not give the answer, even if asked directly — it narrows
> the question instead, until the engineer gets there themselves.

To keep this from becoming a wall no one can get past, there's a limit: after
2 honest attempts, the agent switches to giving hints — a nudge, then a more
specific hint, then a small worked example — before finally just explaining
it. Nobody is stuck forever. And it only kicks in for the concept the task is
meant to teach — quick lookups (syntax, an API name) get answered right away,
no games.

## A real example

**Task:** "Add a feature that counts each time a user logs in."

**Without this method**, the agent just writes it:

```python
def record_login(user_id):
    user = db.get_user(user_id)
    user.login_count = user.login_count + 1
    db.save_user(user)
```

It looks correct. It passes a quick test. The junior ships it. Months later,
under real traffic, the login count is quietly wrong — because when two
logins happen at almost the same instant, both read the same starting
number, both add one, and one of the increments is lost. Nobody notices until
someone questions the analytics dashboard, and by then nobody remembers this
code, let alone why it's wrong.

**With this method**, the dialogue looks more like this:

> **Agent:** Before I write this — imagine two logins for the same user
> happen at almost the exact same moment. Walk me through what each one
> reads, and what each one writes. What does `login_count` end up as?
>
> **Junior:** I guess it would be 42, since it just adds one each time?
>
> **Agent:** Let's slow that down. Say `login_count` starts at 40. Login A
> reads it — what value does it see? Then, before A writes anything back,
> login B also reads it. What value does *B* see?
>
> **Junior:** ...both would see 40, since neither has written yet.
>
> **Agent:** Right. So both compute 41 and write 41. What happened to the
> second login?
>
> **Junior:** Oh — it's lost. We did two logins but the count only went up
> by one.

That's the real issue: reading a value and writing it back later isn't a
single, uninterruptible step — something else can happen in between. The fix
is to make the increment atomic, e.g. doing it in one database statement
instead of a separate read and write:

```sql
UPDATE users SET login_count = login_count + 1 WHERE id = ?
```

Now the junior will recognize this exact shape of bug (a "lost update") in
every future counter, balance, or inventory field they touch. That's the
entire point: the value isn't this one bug fixed, it's a pattern learned once
that generalizes to every version of it going forward.

## Beyond writing code

A junior engineer's job is bigger than an intern's — they own features
end-to-end, get paged, review other people's code, and give estimates. So
this method covers seven points where learning actually happens, not just
three:

1. **Pre-coding** — explain the problem back, in your own words, before any code exists.
2. **Design review** — question the tradeoffs and failure modes before committing to an approach.
3. **Development** — small pieces of code, checked for understanding, not one big dump.
4. **Pre-submission** — the agent plays a strict senior reviewer before the PR goes out.
5. **Reviewing someone else's PR** — good questions instead of a rubber stamp.
6. **Postmortem debugging** — once an incident is over, root-cause questions instead of a diagnosis handed to you.
7. **Estimation** — questions that surface the hidden complexity before you commit to a deadline.

Two built-in exceptions, on purpose. This only applies to work worth learning
from — a typo fix doesn't need a Socratic dialogue, the agent uses judgment
and skips straight to trivial changes. And it never applies **during** a live
incident — while something is actually down, you want fast help, not guided
discovery; the questions belong in the postmortem afterward. You can also
override it yourself at any time — "skip this, I'm on call" gets you a direct
answer, no argument. That override still gets logged (see below) rather than
silently dropped — if you're overriding the same topic constantly, that's a
pattern worth you noticing, not something that should vanish quietly.

One more thing worth calling out: on day one, every topic in your mastery
file defaults to "new" — which would mean the heaviest, most question-heavy
version of this hits right when you're still deciding whether it's worth
keeping. So the first stretch (roughly your first 10 non-trivial tasks) is
meant to run lighter than full strength on purpose, regardless of what the
file says, and ramp up from there. A method that feels like a wall on day one
gets turned off on day one.

## Tracking what's actually learned (and easing off once it's real)

Every phase above ends with a quick update to a personal, private "mastery
file" — a plain markdown list of concepts and how solid your understanding of
each one is (`new`, `developing`, `mastered`, `needs-revisit`, or
`skipped-override` for a topic you overrode past).

This does two things. First, for any given task, you can pull a short,
specific takeaway out of it — "learned that read-then-write isn't atomic" —
and put *that one line* in the PR description, so a reviewer sees what you
learned, not just what you shipped. The full file itself should stay private
(more on why below) — what goes in the PR is a one-line summary of that
task's takeaway, not the file itself. Second — and this is the part that matters for someone using this for years,
not just an internship — once a topic is solidly `mastered`, the agent stops
interrogating you about it and just moves fast. It saves the real Socratic
treatment for what's still genuinely new. This idea (support a lot at first,
less as skill grows) has a name in learning research: **cognitive
apprenticeship** (Collins, Brown & Newman, 1989 —
[summary](https://www.aft.org/ae/winter1991/collins_brown_holum)). The
Socratic method is the *how you ask*; cognitive apprenticeship is *how much
you ask, over time*.

Keep this file **local to you**, not in a shared repo — it can reveal your
own skill gaps, and it can reference real code you've worked on. If you need
it to follow you across machines, a **private** git repo works; never make
it public. It's yours, full stop — it's not a performance-review artifact,
and a manager shouldn't be asking to see it.

## Making it automatic (so you don't re-explain it every time)

The whole point is that you shouldn't have to paste a prompt into every new
chat. The actual instruction files, plus a step-by-step setup guide for
Claude Code (terminal or the "Code" tab in the Claude Desktop app — the
Desktop app's separate Chat and Cowork tabs don't share this mechanism) and
Codex CLI, are here:

**→ [github.com/akshayrao14/git-practices](https://github.com/akshayrao14/git-practices)** (see the `socratic-method` folder)

Short version: the files live at the *user* level (your own machine's config),
not inside any one repo — because this is about training *you*, not one
codebase, and it should apply the moment you open any project, including ones
you haven't touched yet.

## Extending this to other agents

This is written to work with Claude Code first, since that's what I use day
to day. It's built on `AGENTS.md`, an open format already read
by Codex, Cursor, GitHub Copilot, Aider, Zed, Windsurf, and others — so most
of it works elsewhere with little to no change. The repo above includes setup
notes for Codex CLI specifically. If you're on a different tool and get this
working, I'd genuinely like to hear how — open an issue on the repo.

## What I'm still unsure about

Being honest about the limits: this leans on the agent actually following
long-running instructions faithfully, which isn't guaranteed — especially
across a long session. It also assumes you'll actually maintain the mastery
file; nothing forces that except the fact that it's tied to steps you already
have to do anyway (like writing a PR description).

There's also a social risk worth naming: if you're visibly going through a
Socratic back-and-forth on every PR while your peers (who aren't using this)
aren't, that could read as "needs more hand-holding" to someone who doesn't
know why. If this feels true for your team, it's worth deciding for yourself
whether and how visibly you use it — this is meant to help you learn, not to
be performed for anyone.

If you try this and it breaks down somewhere, that's useful information —
tell me.
