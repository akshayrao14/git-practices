#!/bin/bash
source bash_formatting.sh

# Place this in the folder which contains all your repos. Do not place it in the
# root of any particular repo.
#
# run this from the root directory of any repo. It will merge your current branch
# to the supplied target branch (squash and merge)
#
# git checkout my-feature-branch
# ../merge_into.sh development

MERGE_INTO_BRANCH=$1

if test -z "$MERGE_INTO_BRANCH"
then
  echo "No target branch provided."
  echo "Try again."
  exit 1
fi

case $MERGE_INTO_BRANCH in

  development)
    ;;

  demo)
    ;;

  pre-release)
  echo "Not allowed to merge anything into pre-release using this."
  exit
    ;;

  main)
  echo "Not allowed to merge anything into main using this."
  exit
    ;;

  *)
    echo -e "${LIGHT_RED}Invalid target branch: '$MERGE_INTO_BRANCH'"; RESET_FORMATTING
    echo "Only development and demo allowed"
    echo "Try again."
    exit
    ;;
esac

# REPO_NAME=$(basename $(git rev-parse --show-toplevel))
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)


case $CUR_BRANCH in
  development|demo)
    echo -e "${LIGHT_RED}Not allowed to merge '$CUR_BRANCH' into anything."; RESET_FORMATTING
    exit
    ;;
  "$MERGE_INTO_BRANCH")
    echo -e "${LIGHT_RED}Source and destination branches must be different."; RESET_FORMATTING
    exit
    ;;
esac

git fetch origin 2>&1

export LOCAL_CUR_BR="$CUR_BRANCH"
export REMOTE_CUR_BR="origin/$CUR_BRANCH"

if [ "$(git rev-parse "$LOCAL_CUR_BR")" == "$(git rev-parse "$REMOTE_CUR_BR")" ]
then
    echo ""
else
    echo ""
    echo -e "${LIGHT_RED}Your local \"$CUR_BRANCH\" branch is NOT in sync with its remote origin."; RESET_FORMATTING
    echo -e "\tRun\tgit pull origin $CUR_BRANCH"
    echo -e "\t-or-\tcommit/stash/discard the local changes..."
    echo -e "\t-or-\tgit push origin $CUR_BRANCH"
    echo "and rerun merge_into."
    exit 1
fi

echo "Starting the steps to send commits from $CUR_BRANCH to $MERGE_INTO_BRANCH..."

echo -e "${LOW_INTENSITY_TEXT}Switching to $MERGE_INTO_BRANCH..."
git checkout "$MERGE_INTO_BRANCH" 2>&1

echo -e "${LOW_INTENSITY_TEXT}Discarding all unpushed changes of your local $MERGE_INTO_BRANCH branch."
git reset --hard "origin/$MERGE_INTO_BRANCH" 2>&1 && git clean -fd 2>&1

echo -e "${LOW_INTENSITY_TEXT}Pulling latest $MERGE_INTO_BRANCH... from remote."
git pull origin "$MERGE_INTO_BRANCH" 2>&1

echo -e "${LOW_INTENSITY_TEXT}Running GIT MERGE $CUR_BRANCH --SQUASH"
suppress_git_merge_output=$(git merge "$CUR_BRANCH" --squash 2>&1)

IFS=$'\n'; splitLines=($suppress_git_merge_output); unset IFS;
for curLine in "${splitLines[@]}"; do

  if [[ "$curLine" == *"CONFLICT"* ]]; then
    textColor=$LIGHT_RED
  elif [[ "$curLine" == *"merge failed"* ]]; then
    textColor=$CYAN
  elif [[ "$curLine" == *"Auto-merging"* ]]; then
    textColor=$LIGHT_GREEN
  else
    textColor=$LOW_INTENSITY_TEXT
  fi

  echo -e "$textColor > $curLine"
  RESET_FORMATTING
done

export AUTO_COMMIT_MSG="Merge branch '$CUR_BRANCH' into $MERGE_INTO_BRANCH via merge_into.sh"

if [[ "$suppress_git_merge_output" == *"Automatic merge went well"* ]]; then

  echo ""
  echo -e "${LIGHT_GREEN}~ ~ ~ ~ ~ ~ ~ ~ No conflicts! ~ ~ ~ ~ ~ ~ ~ ~"; RESET_FORMATTING
  echo -e "${LIGHT_GREEN}Auto-committing and auto-pushing!"; RESET_FORMATTING
  (
    git commit -m "AutoMerge: $AUTO_COMMIT_MSG" && 
    git push origin "$MERGE_INTO_BRANCH" && 
    git checkout "$CUR_BRANCH"
  ) || echo -e "${LIGHT_RED}\nAutoMerge failed during commit/push. Please check why..."
  RESET_FORMATTING
  exit 0
fi

git status

echo -e "${LIGHT_RED}~ ~ ~ ~ ~ ~ ~ ~ Conflicts OMG ~ ~ ~ ~ ~ ~ ~ ~ "; RESET_FORMATTING
echo ""
echo "Please resolve them, add a new commit and then push it to origin."
echo ""
echo -e "↘ ↘ ↘ ↘ ↓ ↓ ↓ ↓ Copy the command below ↓ ↓ ↓ ↓ ↙ ↙ ↙ ↙"
echo ""
echo "git commit -m \"\" || git add . && git commit -m \"$AUTO_COMMIT_MSG\" -n && git push origin $MERGE_INTO_BRANCH && git checkout $CUR_BRANCH"

echo ""
echo -e " ↗ ↗ ↗ ↗ ~ ~ ~ ~ ~ ~ ~ ~ ↑ ↑ ↑ ↑ ~ ~ ~ ~ ~ ~ ~ ↖ ↖ ↖ ↖"
echo ""

# Save state of this merge to .git/merge_into.state
echo "Conflicts: $AUTO_COMMIT_MSG" > .git/merge_into.state
echo "ManualMerge: $AUTO_COMMIT_MSG" > .git/merge_into.commit-msg
