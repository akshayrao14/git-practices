#!/bin/bash
# echo $(pwd)
source "$(dirname $0)/helpers/spinner.sh"

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
  
  script_dir=$1
  
  cd "$script_dir" || (echo -e "${LIGHT_RED}Unable to find the script directory!")
  cd ..

  sup_fetch=$(git fetch --all --prune 2>&1)

  GIT_PRAC_CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  export GIT_PRAC_CUR_BRANCH
  echo -e "${LOW_INTENSITY_TEXT}Using git-practices branch: $GIT_PRAC_CUR_BRANCH"

  branch_update_list=("main" "beta")
  # loop through branch_update_list and check if the current branch is in the list
  for branch in "${branch_update_list[@]}"; do
    if [[ "$GIT_PRAC_CUR_BRANCH" == "$branch" ]]; then
      # Pull latest changes into branch
      suppress_git_pull=$(git_pull "$GIT_PRAC_CUR_BRANCH")
    else
      # Pull latest changes into branch without git checkout
      suppress_git_pull=$(git fetch origin "$branch":"$branch")
    fi
  done
  RESET_FORMATTING
}

########################################################################
# Check if vscode exists                                               #
########################################################################
ask_make_vscode_mergetool(){
  if command -v code &> /dev/null
  then

    # ask if to set vscode as merge tool or not
    echo -e "${CYAN}Do you want to set vscode as mergetool? Life will be easier. (y/n)"; RESET_FORMATTING
    read -r -n 1 -s answer
    echo -e ""

    if [[ "$answer" == "y" ]]
    then
      echo -e "${LOW_INTENSITY_TEXT}Setting vscode as merge tool..."; RESET_FORMATTING
      set_vscode_mergetool
    else
      echo -e "${LOW_INTENSITY_TEXT}Consider using a mergetool..."; RESET_FORMATTING
    fi
  else
    echo -e "${LOW_INTENSITY_TEXT}VSCODE not found. Consider using a mergetool..."; RESET_FORMATTING
  fi
}

########################################################################
# Set the vscode merge tool                                            #
########################################################################
set_vscode_mergetool(){
  echo -e "${LOW_INTENSITY_TEXT}Setting vscode mergetool..."; RESET_FORMATTING

  git config --global merge.guitool vscode
  git config --global merge.tool vscode
  git config --global mergetool.vscode.cmd 'code --wait $MERGED --new-window'

  git config --global mergetool.vscode.keepBackup false
}


########################################################################
# Checking if merge conflicts exist                                    #
########################################################################
has_merge_conflicts(){
conflicts=$(git diff -S "<<<<<<< HEAD" -S "=======" -S ">>>>>>> $(git name-rev --name-only MERGE_HEAD)" HEAD 2>&1)
  if [ -n "$conflicts" ]; then
    echo -e "${LIGHT_RED}merge_into: ${LOW_INTENSITY_TEXT}Detected merge conflicts. Please resolve it before continuing."; RESET_FORMATTING
  fi
  echo ""
}


testVariables(){
  echo "testVariables SAVED_AUTO_COMMIT_MSG: $SAVED_AUTO_COMMIT_MSG"
  echo "testVariables SAVED_MERGE_INTO_BRANCH: $SAVED_MERGE_INTO_BRANCH"
  echo "testVariables SAVED_CUR_BRANCH: $SAVED_CUR_BRANCH"
  echo "testVariables: $SAVED_AUTO_COMMIT_MSG"
}

########################################################################
# Git wrappers                                                         #
########################################################################
  # git_push <branch>
  #
  # Pushes the given branch to the origin.
git_push() {
  git push origin $1 2>&1
}

  # git_pull <branch>
  #
  # Pulls the given branch from the origin.
git_pull(){
  git pull origin "$1"
}

  # git_commit_blank
  #
  # Commit with an empty message. If there are any errors/warnings, exit with
  # non-zero status and print out the git output.
git_commit_blank(){
  git_commit_msg ""
}

  # git_commit_msg <msg>
  #
  # Commit with a given message. If there are any errors/warnings, exit with
  # non-zero status and print out the git output.
git_commit_msg(){
  gitCommitOutput=$(git commit -m "$1" 2>&1)
  commitErrors=$(echo "$gitCommitOutput" | grep problem | grep error | grep warning)

  # if commitErrors is not blank, exit with error
  if [ -n "$commitErrors" ]; then
    echo -e "${LIGHT_RED}There are some pre-commit errors!"; RESET_FORMATTING
    echo -e "$gitCommitOutput"
    echo -e "Please try again after resolving and them."
    return 1
  fi
  return 0
}

  # git_clean_branch <branch>
  #
  # Resets the given branch to its state on the remote origin and removes
  # any untracked files and directories. This is a destructive operation
  # and will discard all local changes and untracked files.
git_clean_branch(){
  git reset --hard "origin/$1" 2>&1 && git clean -fd 2>&1
}

########################################################################
# Post conflict resolution flow                                        #
########################################################################
post_conflict_resolution(){
    
    gitCommitOutput=""
    run_with_spinner "${LOW_INTENSITY_TEXT}merge_into: Attempting to trigger pre-commit hooks using an empty commit message... " git_commit_blank
    RESET_FORMATTING

    commitErrors=""
    if test "$commitErrors";
    then
      echo -e "$gitCommitOutput"
      echo -e "${LIGHT_RED}There are some pre-commit errors!"; RESET_FORMATTING
      echo -e "Please try again after resolving and them."
      wrap_up
      exit 1
    fi

    echo -e -n "${LOW_INTENSITY_TEXT}${LINE_CLR}merge_into: no issues with pre-commit hooks!"; RESET_FORMATTING
    # sleep 2
    echo ""
    echo -e -n "${LOW_INTENSITY_TEXT}${LINE_CLR}merge_into: Committing and pushing!"; RESET_FORMATTING
    echo ""
    
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
      # git pull --rebase origin "$SAVED_MERGE_INTO_BRANCH" && 
      git_push "$SAVED_MERGE_INTO_BRANCH" &&
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
}