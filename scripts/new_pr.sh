#!/bin/bash

# echo $(pwd)
REPO_NAME=$(basename `git rev-parse --show-toplevel`)
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_URL="https://github.com/TernTechnologies/$REPO_NAME/pull/new/$CUR_BRANCH"
echo "Branch: $CUR_BRANCH of Repo: $REPO_NAME"
echo "Creating new PR at $PR_URL"
gio open $PR_URL