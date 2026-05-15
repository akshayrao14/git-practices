#!/usr/bin/env bash
# Build a skill's SKILL.md from SKILL.md.tmpl by resolving {{include ...}} directives.
#
# Usage:
#   bash scripts/build-skill.sh <skill-name>
#
# Include syntax:
#   {{include <path-relative-to-skills-root>}}
#
# Rules:
#   - The include directive must occupy the entire line (regex anchored ^...$).
#     Mid-line or in-prose `{{include ...}}` text is emitted verbatim.
#   - Path resolved relative to skills/ root.
#   - Single-pass only (no recursive resolution).
#   - Path traversal outside skills/ is rejected.
#   - Missing include file aborts with source-line reference.
#   - Reserved skill names: _shared and any name starting with _ or .
#
# Pre-build: if the destination SKILL.md has uncommitted local edits, prints a
# warning before overwriting (since the canonical source of truth is .tmpl).

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <skill-name>" >&2
  exit 1
fi

SKILL="$1"

if [[ -z "$SKILL" || "$SKILL" == _* || "$SKILL" == .* ]]; then
  echo "build-skill: reserved or invalid skill name: $SKILL" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILLS_ROOT="$REPO_ROOT/skills"
TMPL="$SKILLS_ROOT/$SKILL/SKILL.md.tmpl"
OUT="$SKILLS_ROOT/$SKILL/SKILL.md"

if [[ ! -f "$TMPL" ]]; then
  echo "build-skill: template not found: $TMPL" >&2
  exit 1
fi

if [[ -f "$OUT" ]] && ! git -C "$REPO_ROOT" diff --quiet HEAD -- "$OUT" 2>/dev/null; then
  echo "build-skill: WARNING — $OUT has uncommitted local edits (staged or unstaged) that will be overwritten by the build." >&2
fi

SKILLS_REAL="$(realpath "$SKILLS_ROOT")"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_OUT="$TMP_DIR/SKILL.md"

INCLUDES=0
LINENO_TMPL=0

while IFS= read -r line || [[ -n "$line" ]]; do
  LINENO_TMPL=$((LINENO_TMPL + 1))
  if [[ "$line" =~ ^[[:space:]]*\{\{include[[:space:]]+([^}]+)\}\}[[:space:]]*$ ]]; then
    RELPATH="${BASH_REMATCH[1]}"
    RELPATH="${RELPATH#"${RELPATH%%[![:space:]]*}"}"
    RELPATH="${RELPATH%"${RELPATH##*[![:space:]]}"}"
    TARGET="$SKILLS_ROOT/$RELPATH"
    if [[ ! -f "$TARGET" ]]; then
      echo "build-skill: missing include: $RELPATH (referenced by $TMPL:$LINENO_TMPL)" >&2
      exit 1
    fi
    RESOLVED="$(realpath "$TARGET")"
    if [[ "$RESOLVED" != "$SKILLS_REAL"/* ]]; then
      echo "build-skill: include path escapes skills/ root: $RELPATH (referenced by $TMPL:$LINENO_TMPL)" >&2
      exit 1
    fi
    cat "$RESOLVED" >> "$TMP_OUT"
    INCLUDES=$((INCLUDES + 1))
  else
    printf '%s\n' "$line" >> "$TMP_OUT"
  fi
done < "$TMPL"

mv "$TMP_OUT" "$OUT"
echo "built: $OUT ($INCLUDES includes resolved)"
