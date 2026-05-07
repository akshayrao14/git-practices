#!/usr/bin/env bash
# Mirror a skill folder under skills/<name>/ to its dedicated published repo.
#
# Usage:
#   bash scripts/publish-skill.sh <skill-name> [tag]
#
# Example:
#   bash scripts/publish-skill.sh dependabot-triage v2.1.2
#
# Skill -> mirror remote map. Add new entries here when publishing more skills.
set -euo pipefail

declare -A MIRROR_REMOTES=(
  [dependabot-triage]="https://github.com/akshayrao14/dependabot-triage.git"
)

SKILL="${1:-}"
TAG="${2:-}"

if [[ -z "$SKILL" ]]; then
  echo "Usage: $0 <skill-name> [tag]"
  echo "Known skills: ${!MIRROR_REMOTES[*]}"
  exit 1
fi

REMOTE_URL="${MIRROR_REMOTES[$SKILL]:-}"
if [[ -z "$REMOTE_URL" ]]; then
  echo "Unknown skill: $SKILL"
  echo "Known skills: ${!MIRROR_REMOTES[*]}"
  exit 1
fi

PREFIX="skills/$SKILL"
if [[ ! -d "$PREFIX" ]]; then
  echo "Skill folder not found: $PREFIX"
  exit 1
fi

REMOTE_NAME="mirror-$SKILL"
if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

echo ">>> Subtree-pushing $PREFIX to $REMOTE_NAME ($REMOTE_URL)"
git subtree push --prefix="$PREFIX" "$REMOTE_NAME" main

if [[ -n "$TAG" ]]; then
  TMP_DIR="$(mktemp -d)"
  echo ">>> Tagging $TAG on mirror in $TMP_DIR"
  git clone --depth=1 "$REMOTE_URL" "$TMP_DIR/mirror" >/dev/null 2>&1
  (
    cd "$TMP_DIR/mirror"
    git tag -a "$TAG" -m "$SKILL $TAG"
    git push origin "$TAG"
  )
  rm -rf "$TMP_DIR"
  echo ">>> Tag $TAG pushed. Create the GitHub release manually:"
  echo "    gh release create $TAG --repo $(echo "$REMOTE_URL" | sed 's|https://github.com/||;s|.git$||')"
fi

echo ">>> Done."
