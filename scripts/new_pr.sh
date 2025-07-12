#!/bin/bash

# echo $(pwd)

# get first argument and save it as requested base branch
requested_base_branch=$1

# if requested base branch is empty, then use it as base branch
if [ -z "$requested_base_branch" ]; then
    BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
else
    BASE_BRANCH=$requested_base_branch
fi

REPO_NAME=$(basename `git rev-parse --show-toplevel`)
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR_URL="https://github.com/TernTechnologies/$REPO_NAME/pull/new/$BASE_BRANCH...$CUR_BRANCH"
echo "Branch: $CUR_BRANCH of repo: $REPO_NAME (base: $BASE_BRANCH)"
echo "Creating new PR at $PR_URL"
gio open "$PR_URL"