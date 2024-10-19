#!/bin/bash
source "$(dirname $0)/bash_formatting.sh"

# git checkout my-feature-branch
# ../merge_into.sh development

########################################################################
CUR_VERSION="1.1.2"
SCRIPT_NAME="merge_into.sh"

wrap_up(){
  echo -e ""
  echo -e "${LOW_INTENSITY_TEXT}Thanks for using git-practices!\nSuggestions? Please let the developer know!"
  echo -e "${LOW_INTENSITY_TEXT_DIM}To become a beta-tester, switch to the 'beta' branch in your git-practices repo :)"
  RESET_FORMATTING
  exit 0
}

########################################################################
# Get the latest git-practices code first                              #
########################################################################
# Maintaining the merge_into script: take auto pull from repo - best effort
update_git_practices(){
  echo -e "${LOW_INTENSITY_TEXT}Updating git-practices...";

  script_dir=$1
  
  cd "$script_dir" || exit 0
  cd ..

  sup_fetch=$(git fetch --all --prune 2>&1)

  GIT_PRAC_CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  export GIT_PRAC_CUR_BRANCH
  echo -e "${LOW_INTENSITY_TEXT}Using git-practices branch: $GIT_PRAC_CUR_BRANCH"
  RESET_FORMATTING

  branch_update_list=("main" "beta")
  # loop through branch_update_list and check if the current branch is in the list
  for branch in "${branch_update_list[@]}"; do
    if [[ "$GIT_PRAC_CUR_BRANCH" == "$branch" ]]; then
      # Pull latest changes into branch
      suppress_git_pull=$(git pull origin "$GIT_PRAC_CUR_BRANCH" 2>&1)
    else
      # Pull latest changes into branch without git checkout
      suppress_git_pull=$(git fetch origin "$branch":"$branch" 2>&1)
    fi
  done
}

cur_dir=$(pwd)
update_git_practices "$(echo $(dirname "$0"))"
cd "$cur_dir" || exit

########################################################################
# Read the argument values
commit_state_file=.git/merge_into.state
case $1 in
  --abort)
    echo -e "${LOW_INTENSITY_TEXT}merge_into: $1 flag found. Running post-conflict resolution flow..."; RESET_FORMATTING

    if [ ! -f $commit_state_file ]; then
        echo -e "${LIGHT_RED}No recent merge_into activity detected. Are you sure about this?"; RESET_FORMATTING
        echo -e "${LOW_INTENSITY_TEXT}Please go back to your feature branch and restart."
        wrap_up
        exit 1;
    fi

    source $commit_state_file

    echo -e "${LOW_INTENSITY_TEXT}merge_into: Discarding staged/unstaged changes in ${SAVED_MERGE_INTO_BRANCH}."; RESET_FORMATTING
    sleep 2
    git restore --staged . && git checkout . && git checkout $SAVED_CUR_BRANCH

    wrap_up
    exit 0
    ;;
    
  --continue|--resolve)

    echo -e "${LOW_INTENSITY_TEXT}merge_into: $1 flag found. Running post-conflict resolution flow..."; RESET_FORMATTING
    
    if [ ! -f $commit_state_file ]; then
        echo -e "${LIGHT_RED}No recent merge_into activity detected. Are you sure about this?"; RESET_FORMATTING
        echo -e "${LOW_INTENSITY_TEXT}Please commit and push manually if you're sure."
        wrap_up
        exit 1;
    fi

    sleep 1
    echo -e "${LOW_INTENSITY_TEXT}merge_into: Attempting to trigger pre-commit hooks using an empty commit message..."; RESET_FORMATTING

    sup_runLinters=$(git commit -m "" 2>&1)
    commitErrors=$(echo "$sup_runLinters" | grep problem | grep error | grep warning)
    if test "$commitErrors";
    then
      echo -e "$sup_runLinters"
      echo -e "${LIGHT_RED}There are some pre-commit errors!"; RESET_FORMATTING
      echo -e "Please try again after resolving and them."
      wrap_up
      exit 1
    fi

    echo -e -n "${LOW_INTENSITY_TEXT}${LINE_CLR}merge_into: no issues with pre-commit hooks!"; RESET_FORMATTING
    sleep 2
    echo -e -n "${LOW_INTENSITY_TEXT}${LINE_CLR}merge_into: Committing and pushing!"; RESET_FORMATTING
    echo ""
    source $commit_state_file
    git add -u . # stage modified or deleted files (usually by the pre-commit)
    
    (
      git commit -m "$SAVED_AUTO_COMMIT_MSG" -n
    ) || (
      echo -e "${YELLOW}Strange... Looks like there's nothing to commit... or push."
      RESET_FORMATTING
      echo -e "This usually happens you didn't pick any of your feature branch's changes\n
      while resolving conflicts."
      echo -e "Try it again - abort merge_into and start from the beginning. Run:";
      echo -e "${CYAN}merge_into.sh --abort"
      wrap_up
      exit 1
    )

    (
      git pull --rebase origin "$SAVED_MERGE_INTO_BRANCH" && 
      git push origin "$SAVED_MERGE_INTO_BRANCH" &&
      rm -f $commit_state_file && echo "file removed" &&
      echo -e "${LIGHT_GREEN}Success! Switching back to your original branch '$SAVED_CUR_BRANCH'..." &&
      RESET_FORMATTING &&
      git checkout "$SAVED_CUR_BRANCH" && 
      wrap_up &&
      exit 0
    ) || (
      git restore --staged . &&
      echo -e "${LIGHT_RED}Something went wrong. Try committing/pushing your code manually." && wrap_up
    )

    RESET_FORMATTING
    exit 1
  ;;
esac

MERGE_INTO_BRANCH=$1

if test -z "$MERGE_INTO_BRANCH"
then
  echo -e "${LIGHT_RED}No target branch provided."; RESET_FORMATTING;
  echo -e "Try again."
  wrap_up
  exit 1
fi

case $MERGE_INTO_BRANCH in

  development|demo|develop)
    ;;

  pre-release)
  echo -e "${LIGHT_RED}Not allowed to merge anything into pre-release using this."; RESET_FORMATTING
  wrap_up
  exit
    ;;

  main)
  echo -e "${LIGHT_RED}Not allowed to merge anything into main using this."; RESET_FORMATTING
  wrap_up
  exit
    ;;

  *)
    echo -e "${LIGHT_RED}Invalid target branch: '$MERGE_INTO_BRANCH'"; RESET_FORMATTING
    echo -e "Only development|demo|develop allowed"
    echo -e "Try again."
    wrap_up
    exit
    ;;
esac

# REPO_NAME=$(basename $(git rev-parse --show-toplevel))
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)

case $CUR_BRANCH in
  development|demo|develop)
    echo -e "${LIGHT_RED}Not allowed to merge '$CUR_BRANCH' into anything."; RESET_FORMATTING

    if [ -f $commit_state_file ]; then
      source $commit_state_file
      echo -e "${CYAN}There's seems to be a previously merge_into with the message. Please check."
    fi

    wrap_up
    exit
    ;;
  "$MERGE_INTO_BRANCH")
    echo -e "${LIGHT_RED}Source and destination branches must be different."; RESET_FORMATTING

    wrap_up
    exit
    ;;
esac

echo -e "SAVED_CUR_VERSION=$CUR_VERSION
SAVED_MERGE_INTO_BRANCH=$MERGE_INTO_BRANCH
SAVED_CUR_BRANCH=$CUR_BRANCH
SAVED_AUTO_COMMIT_MSG='$AUTO_COMMIT_MSG'
" > $commit_state_file

# Start the process of merging now.
supFetch=$(git fetch origin --prune 2>&1)

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
    wrap_up
    exit 1
fi

echo -e "${LOW_INTENSITY_TEXT}Starting the steps to send commits from $CUR_BRANCH to $MERGE_INTO_BRANCH..."; RESET_FORMATTING;

echo -e "${LOW_INTENSITY_TEXT_DIM}Switching to $MERGE_INTO_BRANCH..."
git checkout "$MERGE_INTO_BRANCH" 2>&1

RESET_FORMATTING;
echo -e "${CYAN}Discarding all unpushed changes of your local $MERGE_INTO_BRANCH branch.\n"; RESET_FORMATTING;
echo -e "${LOW_INTENSITY_TEXT}Press Ctrl+C to cancel..."; RESET_FORMATTING;
sleep 5
echo -e "${LOW_INTENSITY_TEXT_DIM}";
git reset --hard "origin/$MERGE_INTO_BRANCH" 2>&1 && git clean -fd 2>&1
RESET_FORMATTING;

echo -e "${LOW_INTENSITY_TEXT_DIM}${LINE_CLR}Pulling latest $MERGE_INTO_BRANCH... from remote."
git pull origin "$MERGE_INTO_BRANCH" 2>&1

RESET_FORMATTING;
echo -e "${CYAN}Running GIT MERGE $CUR_BRANCH"; RESET_FORMATTING;
sleep 1

AUTO_COMMIT_MSG="Merge branch '$CUR_BRANCH' into '$MERGE_INTO_BRANCH' via $SCRIPT_NAME (v$CUR_VERSION - $GIT_PRAC_CUR_BRANCH)"
suppress_git_merge_output=$(git merge "$CUR_BRANCH" -m "AutoMerge: $AUTO_COMMIT_MSG" 2>&1)

IFS=$'\n'; splitLines=($suppress_git_merge_output); unset IFS;
for curLine in "${splitLines[@]}"; do

  if [[ "$curLine" == *"CONFLICT"* ]]; then
    textFormatStart="${LINE_CLR}${LIGHT_RED}"
    textFormatEnd="\n"
  elif [[ "$curLine" == *"merge failed"* ]]; then
    textFormatStart="${LINE_CLR}${CYAN}"
    textFormatEnd="\n"
  elif [[ "$curLine" == *"Auto-merging"* ]]; then
    textFormatStart="${LINE_CLR}${LIGHT_GREEN}"
    textFormatEnd=""
  else
    textFormatStart="${LINE_CLR}$LOW_INTENSITY_TEXT"
    textFormatEnd="\n"
  fi
  sleep 0.2
  echo -e -n "${textFormatStart} > $curLine${textFormatEnd}"

  RESET_FORMATTING
done

# Save state of this merge to .git/merge_into.state
echo -e "
SAVED_AUTO_COMMIT_MSG='$AUTO_COMMIT_MSG'
" >> $commit_state_file

if [[ "$suppress_git_merge_output" != *"CONFLICT"* ]]; then

  echo ""
  echo -e "${LIGHT_GREEN}~ ~ ~ ~ ~ ~ ~ ~ No conflicts! ~ ~ ~ ~ ~ ~ ~ ~"; RESET_FORMATTING
  echo -e "${LIGHT_GREEN}Auto-committing and auto-pushing!"; RESET_FORMATTING

  echo -e "${LOW_INTENSITY_TEXT_DIM}"
  (
    # git commit -m "AutoMerge: $AUTO_COMMIT_MSG" && 
    
    git push origin "$MERGE_INTO_BRANCH" && 
    rm -f $commit_state_file && RESET_FORMATTING &&
    echo -e "${LIGHT_GREEN}Success! Switching back to your original branch '$CUR_BRANCH'..." && 
    git checkout "$CUR_BRANCH"
  ) || echo -e "${LIGHT_RED}\nAutoMerge failed during commit/push. Please check why..."
  RESET_FORMATTING
  wrap_up
  exit 0
fi

sleep 2
echo ""
git status

sleep 1
echo -e "";
echo -e "${LIGHT_RED}\t\tSummary"; RESET_FORMATTING
echo -e "${LIGHT_RED}~ ~ ~ ~ ~ ~ ~ ~ Conflicts OMG ~ ~ ~ ~ ~ ~ ~ ~ "; RESET_FORMATTING
echo -e "${YELLOW}Please resolve these locally, then run the commands below to continue:"; RESET_FORMATTING
echo -e "${CYAN}$SCRIPT_NAME --continue ${LOW_INTENSITY_TEXT} to continue merging"; RESET_FORMATTING
echo -e "\tOR"
echo -e "${CYAN}$SCRIPT_NAME --abort ${LOW_INTENSITY_TEXT} to abandon merging"; RESET_FORMATTING
echo -e "";

sleep 2
echo -e "${BLUE_ITAL}A rebase a day, keeps conflicts away!"; RESET_FORMATTING
wrap_up
exit 0
