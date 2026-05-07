#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"

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

TARGET="$SKILLS_HOME/$SKILL_NAME"

mkdir -p "$SKILLS_HOME"

if [[ -L "$TARGET" || -e "$TARGET" ]]; then
  EXISTING="$(readlink "$TARGET" 2>/dev/null || true)"
  if [[ "$EXISTING" == "$SKILL_DIR" ]]; then
    echo "Already installed: $TARGET -> $SKILL_DIR"
    exit 0
  fi
  echo "Refusing to overwrite existing $TARGET"
  echo "Remove it first or set SKILLS_HOME to a different directory."
  exit 1
fi

ln -s "$SKILL_DIR" "$TARGET"
echo "Installed: $TARGET -> $SKILL_DIR"
echo "Restart your agent session (Claude Code, Codex, etc.) to pick up the skill."
