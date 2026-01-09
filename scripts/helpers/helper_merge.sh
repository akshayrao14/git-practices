#!/bin/bash
script_dir=$(dirname "$0")
# shellcheck disable=SC1091
source "$script_dir/helpers/spinner.sh"

########################################################################
# Helper functions - saving and loading commit state
########################################################################
commit_state_file=.git/merge_into.state
load_saved_commit_state(){
    if has_saved_commit_state; then
        # shellcheck disable=SC1090
        source $commit_state_file
    fi
}

discard_saved_commit_state(){
    rm -rf $commit_state_file
}

has_saved_commit_state(){
    if [ -f $commit_state_file ]; then
        return 0
    fi
    return 1
}

write_saved_commit_state(){
    echo -e "$1" > $commit_state_file
}

append_to_saved_commit_state(){
    echo -e "$1" >> $commit_state_file
}

########################################################################
# Helper functions - common wrap up
########################################################################

wrap_up(){
    echo -e ""
    echo -e "${YELLOW}Thanks for using git-practices!\nSuggestions? Please let the developer know!"
    
    # if if_git_practices_beta is false, then it's not a beta-tester
    if ! if_git_practices_beta; then
        echo -e "${LOW_INTENSITY_TEXT}To become a beta-tester, switch to the 'beta' branch in your git-practices repo :)"
    else
        echo -e "${LIGHT_GREEN}Thanks for being a beta-tester! You rock ${RED_BLINK}❤️"
    fi
    
    RESET_FORMATTING
    exit 0
}

########################################################################
# Get the latest git-practices code first                              #
########################################################################

# Show formatted changelog between two commits
show_changelog() {
    local old_ref=$1
    local new_ref=$2
    
    echo -e "\n${CYAN}=== Changelog ===${RESET_FORMATTING}"
    git log --pretty=format:"%h - %s (by %an, %ar)" --abbrev-commit "$old_ref..$new_ref" 2>/dev/null | \
    while IFS= read -r line; do
        # Format different types of commits
        if [[ $line == *"Merge:"* ]]; then
            echo -e "${LOW_INTENSITY_TEXT}$line${RESET_FORMATTING}"
        elif [[ $line == *"fix:"* || $line == *"fix("* ]]; then
            echo -e "${LIGHT_RED}✓ $line${RESET_FORMATTING}"
        elif [[ $line == *"feat:"* || $line == *"feat("* ]]; then
            echo -e "${LIGHT_GREEN}✓ $line${RESET_FORMATTING}"
        elif [[ $line == *"refactor:"* || $line == *"refactor("* ]]; then
            echo -e "${LIGHT_BLUE}↻ $line${RESET_FORMATTING}"
        elif [[ $line == *"docs:"* || $line == *"docs("* ]]; then
            echo -e "${LIGHT_CYAN}✎ $line${RESET_FORMATTING}"
        else
            echo -e "• $line"
        fi
    done
    echo -e "${CYAN}=================${RESET_FORMATTING}\n"
}

# Update git-practices repository with better error handling and reliability
update_git_practices() {
    local cur_pwd script_dir current_branch
    local -i status=0
    
    # Store current directory
    cur_pwd=$(pwd)
    script_dir="$1"
    
    # Change to git-practices root directory
    if ! cd "$script_dir/.." 2>/dev/null; then
        echo -e "${LIGHT_RED}Error: Could not access git-practices directory${RESET_FORMATTING}" >&2
        return 1
    fi
    
    # Get current branch and current commit
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local current_commit
    current_commit=$(git rev-parse HEAD 2>/dev/null)
    
    if [[ -z "$current_branch" || -z "$current_commit" ]]; then
        echo -e "${LIGHT_RED}Error: Could not determine current branch or commit${RESET_FORMATTING}" >&2
        cd "$cur_pwd" || true
        return 1
    fi
    
    # Fetch and prune remote branches
    if ! git_fetch_prune; then
        echo -e "${LIGHT_RED}Warning: Failed to fetch from remote${RESET_FORMATTING}" >&2
        status=1
    fi
    
    # Define branches to update
    local -a branch_update_list=("main" "beta")
    local branch updated=0
    
    # Update each branch
    for branch in "${branch_update_list[@]}"; do
        if [[ "$current_branch" == "$branch" ]]; then
            # For current branch, do a proper pull
            echo -e "${LOW_INTENSITY_TEXT}Updating current branch: $branch${RESET_FORMATTING}"
            
            # Get the remote commit before pulling
            local remote_commit
            remote_commit=$(git rev-parse "origin/$branch" 2>/dev/null)
            
            if ! git_pull "$branch"; then
                echo -e "${LIGHT_RED}Warning: Failed to pull branch $branch${RESET_FORMATTING}" >&2
                status=1
            else
                # Check if we actually got new commits
                local new_commit
                new_commit=$(git rev-parse HEAD 2>/dev/null)
                if [[ "$current_commit" != "$new_commit" && "$new_commit" == "$remote_commit" ]]; then
                    updated=1
                    echo -e "${LIGHT_GREEN}✓ Successfully updated $branch to latest version${RESET_FORMATTING}"
                    show_changelog "$current_commit" "$new_commit"
                fi
            fi
        else
            # For other branches, do a fetch without checkout
            echo -e "${LOW_INTENSITY_TEXT}Updating remote branch: $branch${RESET_FORMATTING}"
            if ! git fetch -q origin "$branch:$branch" 2>/dev/null; then
                echo -e "${LIGHT_RED}Warning: Failed to fetch branch: $branch${RESET_FORMATTING}" >&2
                status=1
            fi
        fi
    done
    
    # If we didn't update but are behind, show what's new
    if [[ $updated -eq 0 && -n "$remote_commit" && "$current_commit" != "$remote_commit" ]]; then
        echo -e "${YELLOW}New updates are available. Run 'git pull' to update.${RESET_FORMATTING}"
        echo -e "${LOW_INTENSITY_TEXT}Changes since your current version:${RESET_FORMATTING}"
        show_changelog "$current_commit" "$remote_commit"
    fi
    
    # Return to original directory
    cd "$cur_pwd" 2>/dev/null || true
    
    # Return status (0 = success, 1 = partial/failure)
    return $status
}

set_git_practices_branch(){
    cur_pwd=$(pwd)
    script_dir=$1
    cd "$script_dir" || (echo -e "${LIGHT_RED}Unable to find the script directory!")
    cd ..
    GIT_PRAC_CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    cd "$cur_pwd" || exit
}

if_git_practices_beta(){
    if [[ "$GIT_PRAC_CUR_BRANCH" == "beta" ]]; then
        return 0
    fi
    return 1
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
    # shellcheck disable=SC2016
    git config --global mergetool.vscode.cmd 'code --wait $MERGED'
    git config --global mergetool.keepBackup false
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

########################################################################
# Git wrappers                                                         #
########################################################################
# git_push <branch>
#
# Pushes the given branch to the origin.
git_push() {
    git push origin "$1" 2>&1
    local _ret=$?
    if [ $_ret -ne 0 ] ; then
        echo -e "${LIGHT_RED}Error while performing '$FUNCNAME'!";
        return $_ret
    fi
    RESET_FORMATTING
}

# git_pull <branch>
#
# Pulls the given branch from the origin.
git_pull(){
    if ! git_branch_in_sync_with_remote "$1"
    then
        git pull origin "$1" 2>&1
        local _ret=$?
        if [ $_ret -ne 0 ] ; then
            echo -e "${LIGHT_RED}Error while performing '$FUNCNAME'!";
            return $_ret
        fi
        RESET_FORMATTING
    fi
}

git_fetch_prune(){
    git fetch --all --prune 2>&1 || echo -e "${LIGHT_RED}Error while fetching and pruning!"
    RESET_FORMATTING
}

# git_commit_blank
#
# Commit with an empty message. If there are any errors/warnings, exit with
# non-zero status and print out the git output.
git_commit_blank(){
    git_commit_msg ""
}

git_checkout() {
    git checkout "$1" 2>&1
    local _ret=$?
    if [ $_ret -ne 0 ] ; then
        echo -e "${LIGHT_RED}Error while performing '$FUNCNAME'!";
        return $_ret
    fi
}

# git_commit_msg <msg>
#
# Commits changes with the provided message. If there are any errors or warnings
# during the commit process (detected by checking the output for specific keywords),
# the function exits with a non-zero status and prints the error messages.
#
# Arguments:
#   $1: The commit message to be used for the git commit.
#
# Returns:
#   0 if the commit is successful without errors or warnings.
#   1 if there are any pre-commit errors or warnings.
#
git_commit_msg(){
    gitCommitOutput=$(git commit -m "$1" 2>&1)
    commitErrors=$(echo "$gitCommitOutput" | grep error | grep warning | grep fatal)
    
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
    git reset --hard "origin/$1" 2>&1 && git clean -fd 2>&1  2>&1 || echo -e "${LIGHT_RED}Error while performing git reset/clean!"
}

git_branch_in_sync_with_remote(){
    if [ "$(git rev-parse "$1")" == "$(git rev-parse "origin/$1")" ]
    then
        return 0
    fi
    return 1
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
    )
    
    (
        # git pull --rebase origin "$SAVED_MERGE_INTO_BRANCH" &&
        git_push "$SAVED_MERGE_INTO_BRANCH" &&
        rm -f "$commit_state_file" && echo "file removed" &&
        echo -e "${LIGHT_GREEN}Success! Switching back to your original branch '$SAVED_CUR_BRANCH'..." &&
        RESET_FORMATTING &&
        git_checkout "$SAVED_CUR_BRANCH" &&
        wrap_up
        ) || (
        git restore --staged . &&
        echo -e "${LIGHT_RED}Something went wrong. Try committing/pushing your code manually." && wrap_up
    )
    
    RESET_FORMATTING
    exit 1
}
