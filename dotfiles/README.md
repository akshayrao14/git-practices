# bashrc.overrides

A personal Bash configuration layer — opinionated Git shortcuts, worktree helpers, AWS SSM/SSO aliases, and a few general-purpose utilities.

Source this file from your `.bashrc` or `.bash_profile`:

```bash
source ~/bashrc.overrides
```

---

## Dependencies

| Tool                              | Required | Purpose                                                               |
| --------------------------------- | -------- | --------------------------------------------------------------------- |
| [`starship`](https://starship.rs) | Optional | Shell prompt (gracefully skipped if absent)                           |
| `git`                             | Yes      | All `g*` aliases and worktree functions                               |
| `git-completion.bash`             | Optional | Tab-completion for Git commands (expected at `~/git-completion.bash`) |
| `aws` CLI                         | Optional | `sso`, `ssmlist` aliases                                              |
| `ssm_login.py`                    | Optional | SSM session helper (must be on `PATH`)                                |
| `merge_into.sh`                   | Optional | Branch merge helper (must be on `PATH`)                               |
| `windsurf`                        | Optional | `wd` alias                                                            |

---

## Configuration

There is a clearly marked section at the top for personal overrides:

```bash
## ---- MAKE YOUR CHANGES HERE ---- ##
export AWS_PROFILE=        # Set your AWS SSO profile name
PATH=$PATH:...             # Append any extra paths
## ---- END OF CHANGES ---- ##
```

---

## Git Aliases

| Alias       | Expands to                                           | Description                      |
| ----------- | ---------------------------------------------------- | -------------------------------- |
| `gs` / `sd` | `git status`                                         | Show working tree status         |
| `gd` / `df` | `git difftool -y`                                    | Open diff tool                   |
| `gco`       | `git checkout`                                       | Checkout a branch                |
| `gcopr`     | `git checkout pre-release`                           | Checkout `pre-release`           |
| `gcom`      | `git checkout main`                                  | Checkout `main`                  |
| `gpp`       | `git checkout -`                                     | Toggle to previous branch        |
| `gadd`      | `git add -u`                                         | Stage tracked files              |
| `grest`     | `git restore --staged .`                             | Unstage everything               |
| `gcmr`      | `git commit -m "[Rao]...`                            | Commit with `[Rao]` prefix       |
| `gcmm`      | `git commit -m ""`                                   | Commit with empty message        |
| `gplo`      | `git pull origin <current-branch>`                   | Pull from origin                 |
| `gpso`      | `git push origin <current-branch>`                   | Push to origin                   |
| `gpsom`     | push + `merge_into.sh`                               | Push then run merge script       |
| `gnew`      | checkout `pre-release`, pull, then `git checkout -b` | Create branch from `pre-release` |
| `gmpr`      | `git merge pre-release`                              | Merge `pre-release` into current |
| `gmm`       | `git merge main`                                     | Merge `main` into current        |
| `gdel`      | `git branch -D`                                      | Delete a local branch            |
| `prdiff`    | `git diff origin/pre-release...HEAD > <branch>.diff` | Export PR diff to file           |
| `full_diff` | `git diff --no-ext-diff pre-release > full_diff.txt` | Full diff against `pre-release`  |
| `gcap`      | `commit_and_push`                                    | See function below               |

---

## AWS Aliases

| Alias              | Description                             |
| ------------------ | --------------------------------------- |
| `sso` / `ssoLogin` | `aws sso login --profile $AWS_PROFILE`  |
| `ssoLogout`        | `aws sso logout --profile $AWS_PROFILE` |
| `ssm`              | `ssm_login.py --session <name>`         |
| `ssmlist`          | `ssm_login.py --list`                   |

---

## Branch-to-Environment Merge Aliases

| Alias    | Description                 |
| -------- | --------------------------- |
| `midev`  | `merge_into.sh development` |
| `midemo` | `merge_into.sh demo`        |

---

## Functions

### `cgb`

Prints the current Git branch name. Used internally by other aliases.

```bash
cgb
# => feature/my-branch
```

### `sanitize_folder_name <name>`

Normalises a string for safe use as a filesystem folder name: lowercases, replaces special characters with underscores, strips leading/trailing underscores, and caps at 255 characters.

### `goToMainWorktree`

`cd`s to the primary worktree root (the first entry from `git worktree list`).

### `createAndGoToNewWorktree <branch-name>`

Creates a new Git worktree at `../worktrees/<repo>/<branch>`, creates the branch, and `cd`s into it.

```bash
createAndGoToNewWorktree feature/my-feature
```

### `commit_and_push <message>` / `gcap`

Safe commit + push pipeline:

1. Aborts if there are any **untracked** files (forces you to be explicit about new files).
2. Runs `gadd` → `git commit -m "[Rao] <message>"` → `gplo --rebase` → `gpso`.

```bash
gcap "fix login redirect"
```

### `RESET_FORMATTING`

Resets terminal text formatting (`tput sgr0`). Used internally by aliases.

---

## Other Aliases

| Alias | Description                           |
| ----- | ------------------------------------- |
| `sz`  | `du -sh` on all items, sorted by size |
| `wd`  | Open Windsurf editor                  |
| `ag`  | Run `antigravity -r`                  |

---

## rao-terminal-theme — per-repo deterministic terminal colours

Shipped as `dotfiles/rao-terminal-theme.sh`. Sourced by `bashrc.overrides` if symlinked into `~/.config/`.

Each git repo under your scope dir gets a unique colour scheme picked deterministically from the repo's folder name. Same name → same colours, every machine, every terminal, forever. Tab title shows `repo (branch)`. Light/dark modes supported; can follow GNOME's system colour-scheme automatically.

### Install

```bash
# 1. Clone this repo somewhere (e.g. ~/tern-work/git-practices)
# 2. Symlink the theme engine into ~/.config so bashrc.overrides can find it
ln -s ~/tern-work/git-practices/dotfiles/rao-terminal-theme.sh ~/.config/rao-terminal-theme.sh

# 3. Symlink bashrc.overrides into your home dir (or source it however you prefer)
ln -s ~/tern-work/git-practices/dotfiles/bashrc.overrides ~/rao_bashrc_overrides

# 4. Ensure ~/.bashrc sources it (Debian/Ubuntu default already does):
#    if [ -f ~/rao_bashrc_overrides ]; then . ~/rao_bashrc_overrides; fi

# 5. (Optional) Set your scope dir if it isn't ~/tern-work
echo 'export RAO_THEME_SCOPE_DIR=$HOME/my-projects' >> ~/.bashrc   # before sourcing

# 6. Open a new terminal, cd into a repo. Background colour should change.
```

### Commands

| Command                          | Description                                                |
| -------------------------------- | ---------------------------------------------------------- |
| `rao-theme`                      | Show current repo, hue, mode, accent                       |
| `rao-theme list`                 | List all repos in scope dir + their assigned hues          |
| `rao-theme hues`                 | List available hues                                        |
| `rao-theme preview <hue\|repo>`  | Preview a palette without committing                       |
| `rao-theme set <hue>`            | Pin current repo to a hue (writes `.rao-theme` in root)    |
| `rao-theme unset`                | Remove `.rao-theme` pin                                    |
| `rao-theme light` / `dark`       | Force light/dark mode (persists)                           |
| `rao-theme auto`                 | Follow GNOME `color-scheme` (default)                      |
| `rao-theme toggle`               | Flip light ↔ dark                                          |
| `rao-theme reapply`              | Re-apply current theme (after manual mode changes)         |
| `rao-theme reset`                | Reset terminal to default colours                          |

### How the picker works

Repo folder name → `cksum` → modulo 8 → index into `[red, orange, yellow, green, cyan, blue, purple, magenta]`. Deterministic, no central registry. With ~30 repos and 8 hues, expect ~2–3 collisions — resolve any that bother you by dropping a `.rao-theme` file in the repo root containing one of the hue names. That file commits with the repo, so anyone using this script gets the same override.

### Worktrees

Worktrees inherit their parent repo's colour automatically (the engine reads `git rev-parse --git-common-dir` rather than `$PWD`).

### Exported environment

Each `cd` exports: `RAO_THEME_REPO`, `RAO_THEME_HUE`, `RAO_THEME_MODE`, `RAO_THEME_ACCENT`. Hook your prompt, tmux status, or whatever else to these if you want matching accents.

### Compatibility

- Tested on GNOME Terminal (VTE). Should work on any emulator honouring OSC 10/11/12 (Alacritty, Kitty, WezTerm, foot, iTerm2, etc).
- Inside tmux, escape sequences are wrapped in DCS passthrough automatically. Requires `set -g allow-passthrough on` in `~/.tmux.conf`.
- Bash only. Adapting to zsh = swap `PROMPT_COMMAND` for `precmd_functions`.

---

## License

MIT — use freely, attribution appreciated but not required.
