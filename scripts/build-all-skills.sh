#!/usr/bin/env bash
# Build every skill that has a SKILL.md.tmpl.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
shopt -s nullglob
for tmpl in skills/*/SKILL.md.tmpl; do
  name="$(basename "$(dirname "$tmpl")")"
  bash scripts/build-skill.sh "$name"
done
