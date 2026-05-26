#!/usr/bin/env bash
# Install session-loop:
#   1) symlink the umbrella skill into the agent's skills dir
#   2) symlink each command stub under commands/*.md into the agent's commands dir
#
# Refuses to overwrite existing files. Set FORCE=1 to allow replacement of
# stale symlinks pointing elsewhere (still won't overwrite real files).
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"
COMMANDS_SRC="$SKILL_DIR/commands"

# Auto-detect target via SKILLS_HOME (generic) or legacy CLAUDE_SKILLS_HOME.
# Falls back to first existing agent dir, else ~/.agents/skills (open standard).
SKILLS_HOME="${SKILLS_HOME:-${CLAUDE_SKILLS_HOME:-}}"
if [[ -z "$SKILLS_HOME" ]]; then
  if [[ -d "$HOME/.codex" ]]; then
    SKILLS_HOME="$HOME/.codex/skills"
  elif [[ -d "$HOME/.claude" ]]; then
    SKILLS_HOME="$HOME/.claude/skills"
  else
    SKILLS_HOME="$HOME/.agents/skills"
  fi
fi

# The commands dir is the sibling of the skills dir for Claude Code:
#   ~/.claude/skills/   <-- SKILLS_HOME
#   ~/.claude/commands/ <-- COMMANDS_HOME
# Same parent layout for Codex (~/.codex/) and the open agent dir (~/.agents/).
COMMANDS_HOME="${COMMANDS_HOME:-$(dirname "$SKILLS_HOME")/commands}"

mkdir -p "$SKILLS_HOME"
mkdir -p "$COMMANDS_HOME"

link_one() {
  local src="$1"
  local target="$2"
  local label="$3"

  if [[ -L "$target" ]]; then
    local existing
    existing="$(readlink "$target")"
    if [[ "$existing" == "$src" ]]; then
      echo "  = $label already linked: $target"
      return 0
    fi
    if [[ "${FORCE:-0}" == "1" ]]; then
      echo "  ~ $label replacing stale symlink: $target"
      rm "$target"
    else
      echo "  ! $label refuses to overwrite existing symlink: $target -> $existing"
      echo "    Set FORCE=1 to replace, or remove it manually."
      return 1
    fi
  elif [[ -e "$target" ]]; then
    echo "  ! $label refuses to overwrite existing file (not a symlink): $target"
    echo "    Move it aside manually if you want to install session-loop here."
    return 1
  fi

  ln -s "$src" "$target"
  echo "  + $label installed: $target -> $src"
}

echo "Installing session-loop skill"
echo "  skills home:   $SKILLS_HOME"
echo "  commands home: $COMMANDS_HOME"
echo

skill_target="$SKILLS_HOME/$SKILL_NAME"
link_one "$SKILL_DIR" "$skill_target" "skill"

echo
echo "Installing slash command stubs"

shopt -s nullglob
fail=0
for cmd_file in "$COMMANDS_SRC"/*.md; do
  cmd_name="$(basename "$cmd_file")"
  cmd_target="$COMMANDS_HOME/$cmd_name"
  if ! link_one "$cmd_file" "$cmd_target" "  $cmd_name"; then
    fail=1
  fi
done

echo
if [[ $fail -eq 1 ]]; then
  echo "One or more command stubs were not installed. See messages above."
  exit 1
fi

echo "Done."
echo
echo "Restart your agent session to pick up the new skill and commands."
echo
echo "Try:"
echo "  /session-wrap       - end-of-session handoff"
echo "  /session-catchup    - start-of-session rehydrate"
echo "  /session-checkpoint - mid-session light save"
echo "  /session-drift      - reality vs ledger reconcile"
echo "  /session-decide     - log a decision"
echo "  /session-open-loops - scan unresolved threads"
echo "  /session-compact-check - pre-compaction state persistence"
