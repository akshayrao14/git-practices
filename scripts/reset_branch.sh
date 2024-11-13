#!/bin/bash
source "$(dirname $0)/bash_formatting.sh"

# reset_branch.sh TARGET         (assumes source to be pre-release)
# OR
# reset_branch.sh --to TARGET    (assumes source to be pre-release)
# OR
# reset_branch.sh --from SOURCE --to TARGET
# OR
# reset_branch.sh TARGET --merge-into (will merge your (current) feat branch after resetting
#                                     before it pushes to origin)

CUR_VERSION="1.0.5"
SCRIPT_NAME="reset_branch.sh"

####################################################################
# OS stuff
####################################################################
YA_DUDE=1
NA_DUDE= #keep blank

IS_GIT_BASH=$NA_DUDE
IS_MAC_OS=$NA_DUDE

if [[ $OSTYPE == *"darwin"* ]]; then
  CUR_OSTYPE=MAC_OS
  IS_MAC_OS=$YA_DUDE
elif [[ $CUR_OSTYPE == "msys" ]]; then
  CUR_OSTYPE=GIT_BASH
  IS_GIT_BASH=$YA_DUDE
else
  CUR_OSTYPE=$OSTYPE
fi

echo -e "${LOW_INTENSITY_TEXT_DIM}OS Detected: $CUR_OSTYPE"; RESET_FORMATTING
####################################################################

#Read the argument values
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -f | --from)
    source_branch="$2"
    shift
    ;;
  -t | --to)
    dest_branch="$2"
    shift
    ;;
  -m | --merge-into| --merge_into)
    merge_feat_branch=$(git rev-parse --abbrev-ref HEAD)

    disallowed_branches=("development" "demo" "develop" "main" "pre-release" "stag" "staging")
    for disallowed_branch in "${disallowed_branches[@]}"; do
      if [[ "$merge_feat_branch" == "$disallowed_branch" ]]; then
        echo -e "${LIGHT_RED}Not allowed to use the merge-into option to merge '$merge_feat_branch' into '$dest_branch'."; RESET_FORMATTING
        exit 1
      fi
    done

    # Start the process of merging now.
    supFetch=$(git fetch origin --prune 2>&1)

    export LOCAL_CUR_BR="$merge_feat_branch"
    export REMOTE_CUR_BR="origin/$merge_feat_branch"

    if [ "$(git rev-parse "$LOCAL_CUR_BR")" == "$(git rev-parse "$REMOTE_CUR_BR")" ]
    then
        echo ""
    else
        echo ""
        echo -e "${LIGHT_RED}Your local \"$merge_feat_branch\" branch is NOT in sync with its remote origin."; RESET_FORMATTING
        echo -e "\tRun\tgit pull origin $merge_feat_branch"
        echo -e "\t-or-\tcommit/stash/discard the local changes..."
        echo -e "\t-or-\tgit push origin $merge_feat_branch"
        echo "and rerun this."
        exit 1
    fi

    shift
    ;;
  *) dest_branch="$1" ;;
  esac
  shift
done

source_branch="${source_branch:-pre-release}"

if [[ ("$dest_branch" == "pre-release") || ("$dest_branch" == "main") ]]; then
  echo "Not allowed to reset '$dest_branch'"
  exit 1
fi

echo "This will reset the '$dest_branch' branch using the '$source_branch' branch..."

echo -e "${LOW_INTENSITY_TEXT_DIM}"
(
  git checkout "$source_branch" &&
    git pull origin "$source_branch" &&
    (git branch -D "$dest_branch" &>/dev/null || true) &&
    git checkout "$dest_branch"
) || (
  echo -e "${LIGHT_RED}something went wrong while switching branches!"
  exit 1
)
RESET_FORMATTING

# if IS_MAC_OS is true, use -P in grep
get_grep_pattern() {
  local prefix="$1" # Prefix: 'branch'
  local suffix="$2" # Suffix: 'into'
  if [[ "$IS_MAC_OS" == "$YA_DUDE" ]]; then
    echo "-E '${prefix}[^ ]*${suffix}'"
  else
    echo "-P '(?<=${prefix}).*?(?=${suffix})'"
  fi
}

merged_branches_since_last_reset=$(git log --boundary --right-only --oneline pre-release...HEAD |
  eval grep -o $(get_grep_pattern "branch" "into") |
  sed "s/'//g" |
  awk -F', ' '!a[$1 FS $2]++' 2>&1)

# check if merged_branches_since_last_reset is empty after trimming for whitespace
if [[ -z "${merged_branches_since_last_reset// /}" ]]; then
  merged_branches_since_last_reset="none"
fi

# run the below code only if merged_branches_since_last_reset is not empty
if [[ "$merged_branches_since_last_reset" != "none" ]]; then
  echo "$dest_branch contains the following merged branches right now:"

  echo -e "\033[33m$merged_branches_since_last_reset\033[0m"
  echo "If you reset the branch, these commits will be lost."
  echo -e "\033[31mDo you want to continue? (y/n)\033[0m"
  read -n 1 -r -s
  echo ""
  if [[ $REPLY != "y" ]]; then
    echo "Exiting..."
    exit 0
  fi
fi

echo "About to start. Press Ctrl+C within 5s to cancel..."

sleep 5

rm -rf delete.me

echo "Resetting $dest_branch from $source_branch..."

echo -e "${LOW_INTENSITY_TEXT_DIM}"
git reset --hard "$source_branch"

supTempFileAdd=$(touch delete.me && date >delete.me && git add delete.me)

COMMIT_SUBJ="Resetting $dest_branch from $source_branch"
COMMIT_LOST_DATA="Commits from these branches could be lost: \
... \
${merged_branches_since_last_reset:-none}"
COMMIT_MSG="$COMMIT_SUBJ via reset_branch.sh (v$CUR_VERSION). $COMMIT_LOST_DATA"

git commit -m "$COMMIT_MSG" -n && successOp=1 || successOp=0
RESET_FORMATTING

if [[ "$successOp" == "0" ]]; then
  echo -e "${LIGHT_RED}Failed to commit. Exiting..."; RESET_FORMATTING
  exit 1
fi

if test -n "$merge_feat_branch"
then
  echo -e "${LIGHT_GREEN}Merging $merge_feat_branch into $dest_branch..."; RESET_FORMATTING
  git merge "$merge_feat_branch" \
    -m "AutoReset+Merge: Resetting $dest_branch from $source_branch and merge-into $merge_feat_branch via reset_branch.sh (v$CUR_VERSION)" && \
    successOp=1 || successOp=0
fi

if [[ "$successOp" == "0" ]]; then
  echo -e "${LIGHT_RED}Failed to merge. Try this without the --merge-into option. Exiting..."; RESET_FORMATTING
  exit 1
fi

echo -e "${LIGHT_GREEN}Pushing $dest_branch to origin..."; RESET_FORMATTING
echo -e "${LOW_INTENSITY_TEXT_DIM}"
git push origin "$dest_branch" --force && successOp=1 || successOp=0
RESET_FORMATTING

if [[ "$successOp" == "0" ]]; then
  echo -e "${LIGHT_RED}Failed to push. Exiting..."; RESET_FORMATTING
  exit 1
fi

echo -e "${LIGHT_GREEN}Done! Sending out emails to let everyone know..."; RESET_FORMATTING

###################################################################
# Sending an email to alert people that the branch has been reset #
###################################################################
# fetches all the branches of the repo
# delete any local branches whose remote counterpart is deleted
# (helps in case we change the API key)
sup_fetch=$(git fetch --all --prune 2>&1)

# filter the branches and get the one containing the API key
secretPrefix="tern/secrets/mailgun/"
secretSuffix="/end"
secretBranch=$(git branch -a | grep -m 1 $secretPrefix | head -1 | xargs)
mgApiKey=$(echo "$secretBranch" | eval grep -o $(get_grep_pattern "$secretPrefix" "$secretSuffix") | xargs)

repoName="$(basename "$(git rev-parse --show-toplevel)")"
curGitUser=$(git config user.email)

supMailer=$(curl -s --user "api:$mgApiKey" \
  https://api.eu.mailgun.net/v3/mg.tern-group.com/messages \
  -F from='Chugli.ai <chugal.kishore@mg.tern-group.com>' \
  -F to=squad-backend-aaaal75qw57nltfnpd5ipeaenu@terngroup.slack.com \
  -F to=squad-frontend-aaaalmsqdekphutvjpqmqmqnwu@terngroup.slack.com \
  -F subject="$repoName: '$dest_branch' branch reset from '$source_branch' by $curGitUser" \
  -F text="$COMMIT_LOST_DATA")

if test -n "$merge_feat_branch"
then
  echo -e "${LIGHT_GREEN}Success! Switching back to your original branch '$SAVED_CUR_BRANCH'..." &&
  RESET_FORMATTING &&
  git checkout "$merge_feat_branch"
fi