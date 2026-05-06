#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"
SKILLS_HOME="${CLAUDE_SKILLS_HOME:-$HOME/.claude/skills}"
TARGET="$SKILLS_HOME/$SKILL_NAME"

mkdir -p "$SKILLS_HOME"

if [[ -L "$TARGET" || -e "$TARGET" ]]; then
  EXISTING="$(readlink "$TARGET" 2>/dev/null || true)"
  if [[ "$EXISTING" == "$SKILL_DIR" ]]; then
    echo "Already installed: $TARGET -> $SKILL_DIR"
    exit 0
  fi
  echo "Refusing to overwrite existing $TARGET"
  echo "Remove it first or set CLAUDE_SKILLS_HOME to a different directory."
  exit 1
fi

ln -s "$SKILL_DIR" "$TARGET"
echo "Installed: $TARGET -> $SKILL_DIR"
echo "Restart your Claude Code session to pick up the skill."
