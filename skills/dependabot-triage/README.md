# dependabot-triage

Claude Code skill for triaging and fixing Dependabot vulnerability alerts in Node.js repos.

## What it does

Given a Dependabot alert (URL, alert number, or just the package name), Claude will:

1. Fetch alert + advisory details via `gh api`.
2. Rank open alerts using a three-axis framework (impact, reachability, CVSS).
3. Determine the patched version, find the dependent chain, check for direct usage.
4. Add an override in `package.json` (both `pnpm.overrides` and npm `overrides`).
5. Regenerate both lockfiles.
6. Verify the resolved version.
7. Open a PR off the latest remote base branch — one PR per package by default.

Full behavior spec is in [`SKILL.md`](./SKILL.md).

## Install

Clone the repo anywhere, then run the install script:

```bash
git clone https://github.com/akshayrao14/git-practices.git   # anywhere on disk
bash git-practices/skills/dependabot-triage/install.sh
```

The script symlinks this folder into `~/.claude/skills/dependabot-triage`. Restart your Claude Code session afterward so the skill is picked up.

### Custom skills directory

Override the target with `CLAUDE_SKILLS_HOME`:

```bash
CLAUDE_SKILLS_HOME=/path/to/skills bash git-practices/skills/dependabot-triage/install.sh
```

### Uninstall

```bash
rm ~/.claude/skills/dependabot-triage
```

## Prerequisites

- `gh` CLI authenticated against the target repo (`gh auth status`).
- Local clone of the repo whose alerts you're triaging.
- `node`, `pnpm`, and/or `npm` for lockfile regeneration.

## Trigger phrases

Any of these route Claude to this skill in a session:

- "Triage Dependabot alerts in `<repo>`"
- "Which vuln should I fix first? <github.com/.../security/dependabot URL>"
- "Fix Dependabot alert #<N> in this repo"
- "Bump `<pkg>` to a non-vulnerable version"

## Updating

The install is a symlink, so `git pull` in the cloned repo immediately propagates updates. No reinstall needed.
