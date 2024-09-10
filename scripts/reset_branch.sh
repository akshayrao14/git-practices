#!/bin/bash

# reset_branch.sh TARGET         (assumes source to be pre-release)
# OR
# reset_branch.sh --to TARGET    (assumes source to be pre-release)
# OR
# reset_branch.sh --from SOURCE --to TARGET

CUR_VERSION="1.0.3"
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

echo -e "${LOW_INTENSITY_TEXT}OS Detected: $CUR_OSTYPE"
####################################################################

#Read the argument values
while [[ "$#" -gt 0 ]]
  do
    case $1 in
      -f|--from) source_branch="$2"; shift;;
      -t|--to) dest_branch="$2"; shift;;
      *) dest_branch="$1"
    esac
    shift
done

source_branch="${source_branch:-pre-release}"

if [[ ("$dest_branch" == "pre-release") || ("$dest_branch" == "main") ]]
then
  echo "Not allowed to reset '$dest_branch'"
  exit 1
fi

echo "This will reset the '$dest_branch' branch using the '$source_branch' branch..."

echo ""
(
git checkout "$source_branch" && 
git pull origin "$source_branch" && 
(git branch -D "$dest_branch" &>/dev/null || true) &&
git checkout "$dest_branch"
) || (
  echo "something went wrong while switching branches!"
  exit 1
)

# if IS_MAC_OS is true, use -P in grep
if [[ "$IS_MAC_OS" == "$YA_DUDE" ]]; then
  grep_pattern='-E'
else
  grep_pattern='-P'
fi

merged_branches_since_last_reset=$(git log --boundary --right-only --oneline pre-release...HEAD \
| grep -o $grep_pattern '(?<=branch).*(?= into)' \
| sed "s/'//g" \
| awk -F', ' '!a[$1 FS $2]++' 2>&1)

# check if merged_branches_since_last_reset is empty after trimming for whitespace
if [[ -z "${merged_branches_since_last_reset// }" ]]; then
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

echo "Press Ctrl+C within 5s to cancel..."

sleep 5

rm -rf delete.me

echo "Resetting $dest_branch from $source_branch..."
git reset --hard "$source_branch"

supTempFileAdd=$(touch delete.me && date > delete.me && git add delete.me)

COMMIT_SUBJ="Resetting $dest_branch from $source_branch"
COMMIT_LOST_DATA="Commits from these branches could be lost:
...
${merged_branches_since_last_reset:-none}"
COMMIT_MSG="$COMMIT_SUBJ via reset_branch.sh (v$CUR_VERSION). $COMMIT_LOST_DATA"

(git commit -m "$COMMIT_MSG" -n && git push origin $dest_branch --force) || (echo "something went wrong while pushing!" && exit 0)

repoName="$(basename "$(git rev-parse --show-toplevel)")"

# fetches all the branches of the repo
# delete any local branches whose remote counterpart is deleted
# (helps in case we change the API key)
sup_fetch=$(git fetch --all --prune 2>&1)

# filter the branches and get the one containing the API key
secretPrefix="tern/secrets/mailgun/"
secretSuffix="/end"
secretBranch=$(git branch -a | grep -m 1 $secretPrefix | head -1 | xargs)
mgApiKey=$(echo "$secretBranch" | grep -o $grep_pattern "(?<=$secretPrefix).*(?=$secretSuffix)")

curGitUser=$(git config user.email)

supMailer=$(curl -s --user "api:$mgApiKey" \
      https://api.eu.mailgun.net/v3/mg.tern-group.com/messages \
      -F from='Chugli.ai <chugal.kishore@mg.tern-group.com>' \
      -F to=squad-backend-aaaal75qw57nltfnpd5ipeaenu@terngroup.slack.com \
      -F to=squad-frontend-aaaalmsqdekphutvjpqmqmqnwu@terngroup.slack.com \
      -F subject="$repoName: '$dest_branch' branch reset from '$source_branch' by $curGitUser" \
      -F text="$COMMIT_LOST_DATA")

