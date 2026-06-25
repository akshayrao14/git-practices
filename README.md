# git-practices

A personal grab-bag of git workflow tooling, shell config, Claude Code skills, and SQL helpers. Each top-level directory is independent — clone the repo and pull in only what you want.

## What's here

| Path                          | What it is                                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
| [`scripts/`](scripts/)        | Git workflow scripts (merge into ephemeral branches, reset branches, send notifications, AWS SSM helpers).  |
| [`dotfiles/`](dotfiles/)      | Shell config: `bashrc.overrides` (aliases, git/AWS shortcuts) and `repohue` (per-repo terminal colours). See [`dotfiles/README.md`](dotfiles/README.md). |
| [`skills/`](skills/)          | Claude Code skills: `dependabot-triage` + `dependabot-triage-py` (automated CVE triage), `session-loop` (multi-day project pause/resume toolkit). Built from `SKILL.md.tmpl` templates via a `{{include}}` resolver, with reusable fragments under `skills/_shared/`. |
| `.claude/` and `.agents/`     | Claude Code project configuration and agent definitions.                                                    |
| `LLM Custom Instructions.md`  | Custom instructions / coding protocol used with LLMs (skeptical-sparring persona, phased workflow).         |
| `idempotent_constraints.sql`  | Example pattern for idempotent Postgres `ADD CONSTRAINT` migrations.                                        |

## Quick install paths

Pick the parts you want — none of them depend on each other.

### Shell config + per-repo terminal colours

```bash
git clone https://github.com/<your-fork>/git-practices ~/tern-work/git-practices

# Theme engine
ln -s ~/tern-work/git-practices/dotfiles/repohue.sh ~/.config/repohue.sh

# Aliases + helpers (bash)
ln -s ~/tern-work/git-practices/dotfiles/bashrc.overrides ~/rao_bashrc_overrides
echo 'if [ -f ~/rao_bashrc_overrides ]; then . ~/rao_bashrc_overrides; fi' >> ~/.bashrc

# Open a new terminal. cd into any git repo to see colours kick in.
```

Full details and customisation knobs: [`dotfiles/README.md`](dotfiles/README.md).

### Git workflow scripts

Put `scripts/` on your `PATH`:

```bash
echo 'export PATH=$PATH:$HOME/tern-work/git-practices/scripts' >> ~/.bashrc
```

Then use them directly: `merge_into.sh <target-branch>`, `new_pr.sh`, `ssm_login.py`, etc. Most scripts have inline `--help` or are short enough to read.

### Claude Code skills

Each skill lives under `skills/<name>/`. Skills with a `SKILL.md.tmpl` are compiled to `SKILL.md` by resolving `{{include ...}}` directives against shared fragments:

```bash
scripts/build-skill.sh skills/dependabot-triage    # one skill
scripts/build-all-skills.sh                          # every templated skill
```

Publish a skill to its dedicated repo (and auto-build first):

```bash
scripts/publish-skill.sh skills/dependabot-triage
scripts/publish-skill.sh skills/dependabot-triage-py
scripts/publish-skill.sh skills/session-loop
```

## License

MIT — see [`LICENSE`](LICENSE).
