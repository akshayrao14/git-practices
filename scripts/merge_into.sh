#!/bin/bash
source "$(dirname $0)/bash_formatting.sh"
source "$(dirname $0)/helpers/helper_merge.sh"
source "$(dirname $0)/helpers/spinner.sh"

# git checkout my-feature-branch
# merge_into.sh development

########################################################################
CUR_VERSION="1.2.1"
SCRIPT_NAME="merge_into.sh"
cur_dir=$(pwd)

########################################################################
# Read the argument values
########################################################################
commit_state_file=.git/merge_into.state

if [ -f $commit_state_file ]; then
  source $commit_state_file
fi

########################################################################
# Parse the arguments: --abort, --continue or <>
########################################################################
case $1 in
  --abort)
    echo -e "${LOW_INTENSITY_TEXT}merge_into: $1 flag found. Running post-conflict resolution flow..."; RESET_FORMATTING

    if [ ! -f $commit_state_file ]; then
        echo -e "${LIGHT_RED}No recent merge_into activity detected. Are you sure about this?"; RESET_FORMATTING
        echo -e "${LOW_INTENSITY_TEXT}Please go back to your feature branch and restart."
        wrap_up
        exit 1;
    fi

    echo -e "${LOW_INTENSITY_TEXT}merge_into: Discarding staged/unstaged changes in ${SAVED_MERGE_INTO_BRANCH}."; RESET_FORMATTING
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

    post_conflict_resolution
    ;;
  *)
    rm -f $commit_state_file
    ;;
esac

########################################################################
# Validate destination branch
########################################################################
MERGE_INTO_BRANCH=$1

if test -z "$MERGE_INTO_BRANCH"
then
  echo -e "${LIGHT_RED}No target branch provided."; RESET_FORMATTING;
  echo -e "Try again."
  wrap_up
  exit 1
fi
case $MERGE_INTO_BRANCH in

  development|demo|develop|staging|stag)
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
    echo -e "Only development|demo|develop|staging|stag allowed"
    echo -e "Try again."
    wrap_up
    exit
    ;;
esac

########################################################################
# Validate source branch
########################################################################
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

source $commit_state_file

########################################################################
# Setup the process of merging
########################################################################

## Check if the current branch is in sync with its remote origin
supFetch=$(git fetch origin --prune 2>&1)

export LOCAL_CUR_BR="$CUR_BRANCH"
export REMOTE_CUR_BR="origin/$CUR_BRANCH"

if [ "$(git rev-parse "$LOCAL_CUR_BR")" == "$(git rev-parse "$REMOTE_CUR_BR")" ]
then
    echo ""
else
    echo ""
    echo -e "${LIGHT_RED}Your local \"$CUR_BRANCH\" branch is NOT in sync with its remote origin."; RESET_FORMATTING
    echo -e "${YELLOW}\tRun\tgit pull origin $CUR_BRANCH"; RESET_FORMATTING
    echo -e "${CYAN}\t-or-\t${YELLOW}commit/stash/discard the local changes..."; RESET_FORMATTING
    echo -e "${CYAN}\t-or-\t${YELLOW}git push origin $CUR_BRANCH"; RESET_FORMATTING
    echo -e "${LIGHT_RED}and rerun merge_into."; RESET_FORMATTING
    wrap_up
    exit 1
fi

## Checkout the target branch and get a clean version of it from origin
echo -e "${LOW_INTENSITY_TEXT}Starting the steps to MERGE commits from '$CUR_BRANCH' INTO '$MERGE_INTO_BRANCH'...";
echo -e "${LOW_INTENSITY_TEXT_DIM}"
git checkout "$MERGE_INTO_BRANCH" 2>&1
RESET_FORMATTING;

echo -e "${CYAN}About to discard all unpushed changes from ${YELLOW}$MERGE_INTO_BRANCH";
RESET_FORMATTING;

########################################################################
# Update git-practices repo
########################################################################
GIT_PRAC_CUR_BRANCH=
# run_with_spinner \
#   "${LOW_INTENSITY_TEXT}Updating git-practices..." \
#   update_git_practices "$(echo $(dirname "$0"))"
# cd "$cur_dir" || exit
update_git_practices "$(echo $(dirname "$0"))" &

run_with_spinner \
  "${YELLOW}This is a destructive operation (locally). To cancel, press Ctrl+C now..." \
  sleep 5
RESET_FORMATTING

run_with_spinner \
  "${LOW_INTENSITY_TEXT_DIM}Discarding..." \
  git_clean_branch "$MERGE_INTO_BRANCH"
RESET_FORMATTING;

run_with_spinner \
  "${LOW_INTENSITY_TEXT_DIM}${LINE_CLR}Pulling latest $MERGE_INTO_BRANCH... from remote." \
  git_pull "$MERGE_INTO_BRANCH"

RESET_FORMATTING;

########################################################################
# Run GIT MERGE
########################################################################
echo -e "${CYAN}Running GIT MERGE $CUR_BRANCH"; RESET_FORMATTING;
sleep 1
AUTO_COMMIT_MSG="Merge branch '$CUR_BRANCH' into '$MERGE_INTO_BRANCH' via $SCRIPT_NAME (v$CUR_VERSION - $GIT_PRAC_CUR_BRANCH)"
suppress_git_merge_output=$(git merge "$CUR_BRANCH" -m "AutoMerge: $AUTO_COMMIT_MSG" 2>&1)

MERGE_NOT_NEEDED=0

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
    textFormatEnd="\n"
  elif [[ "$curLine" == *"Already up to date"* ]]; then
    MERGE_NOT_NEEDED=1
    textFormatStart="${LINE_CLR}${LIGHT_GREEN}"
    textFormatEnd="\n"
    break
  else
    textFormatStart="${LINE_CLR}$LOW_INTENSITY_TEXT"
    textFormatEnd="\n"
  fi
  sleep 0.2
  echo -e -n "${textFormatStart} > $curLine${textFormatEnd}"

  RESET_FORMATTING
done

########################################################################
# Happy cases!
########################################################################
if [[ "$suppress_git_merge_output" != *"CONFLICT"* ]]; then

  echo ""

  # if MERGE_NOT_NEEDED is 1, we're done
  if [[ "$MERGE_NOT_NEEDED" == "1" ]]; then
    echo -e "${LIGHT_GREEN}~ ~ ~ ~ ~ ~ ~ ~ '$MERGE_INTO_BRANCH' is already up to date ~ ~ ~ ~ ~ ~ ~ ~"; RESET_FORMATTING

    echo -e "${LOW_INTENSITY_TEXT}"
    git checkout "$CUR_BRANCH"
    
    wrap_up
    exit 0
  fi

  echo ""
  echo -e "${LIGHT_GREEN}~ ~ ~ ~ ~ ~ ~ ~ No conflicts! ~ ~ ~ ~ ~ ~ ~ ~"; RESET_FORMATTING
  
  (
    run_with_spinner \
      "${LOW_INTENSITY_TEXT_DIM}Auto-Committing..." \
      git_commit_msg "AutoMerge: $AUTO_COMMIT_MSG" && 
    run_with_spinner \
      "${LOW_INTENSITY_TEXT_DIM}Auto-Pushing..." \
      git_push "$MERGE_INTO_BRANCH" && 
    rm -f $commit_state_file && 
    RESET_FORMATTING &&
    echo -e "${LIGHT_GREEN}Success! Switching back to your original branch '$CUR_BRANCH'..." && 
    git checkout "$CUR_BRANCH"
  ) || echo -e "${LIGHT_RED}\nAutoMerge failed during commit/push. Please check why..."
  RESET_FORMATTING
  wrap_up
  exit 0
fi

########################################################################
# Conflicts!
########################################################################

# Save state of this merge to .git/merge_into.state
echo -e "
SAVED_AUTO_COMMIT_MSG='$AUTO_COMMIT_MSG'
" >> $commit_state_file

echo -e "";

echo -e "${LIGHT_RED}~ ~ ~ ~ ~ ~ ~ ~ Conflicts OMG ~ ~ ~ ~ ~ ~ ~ ~ "; RESET_FORMATTING
echo -e "${BLUE_ITAL}A rebase a day, keeps them conflicts away!"; RESET_FORMATTING
echo ""
run_with_spinner \
  "${LOW_INTENSITY_TEXT}Checking if you have any git mergetool already setup..." \
  sleep 2

########################################################################
# if there's no mergetool, ask if to set vscode as mergetool or not
########################################################################
mergetool_name=$(git config --get merge.tool)
if test -z "$mergetool_name"
then
  ask_make_vscode_mergetool
fi
mergetool_name=$(git config --get merge.tool)

########################################################################
# Run whatever mergetool is present
########################################################################
if test "$mergetool_name"; then
  run_with_spinner \
    "${CYAN}mergetool.name is set to $mergetool_name. Running it now..." \
    sleep 2
  RESET_FORMATTING

  echo -e "${LOW_INTENSITY_TEXT}"
  git mergetool
  RESET_FORMATTING

  retval=$( has_merge_conflicts )
  if [[ "$retval" == "" ]]
  then
      echo -e "${LIGHT_GREEN}Conflicts resolved!"; RESET_FORMATTING
      post_conflict_resolution
      
      exit 0
  else
      run_with_spinner \
        "${CYAN}Checking for conflicts..." \
        sleep 2
      
      echo -e "${LIGHT_RED}Conflicts still detected!"; RESET_FORMATTING
  fi
fi
echo -e "\tACTION NEEDED!"
echo -e "${YELLOW}Please resolve conflicts locally, then run the commands below to continue:"; RESET_FORMATTING
echo -e "${CYAN}$SCRIPT_NAME --continue ${LOW_INTENSITY_TEXT} to continue merging"; RESET_FORMATTING
echo -e "\tOR"
echo -e "${CYAN}$SCRIPT_NAME --abort ${LOW_INTENSITY_TEXT} to abandon merging"; RESET_FORMATTING
echo -e ""

wrap_up
exit 0
