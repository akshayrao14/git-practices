# rao_bashrc_overrides

A personal Bash configuration layer — opinionated Git shortcuts, worktree helpers, AWS SSM/SSO aliases, and a few general-purpose utilities.

Source this file from your `.bashrc` or `.bash_profile`:

```bash
source ~/rao_bashrc_overrides
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

## License

MIT — use freely, attribution appreciated but not required.
