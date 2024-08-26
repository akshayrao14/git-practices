#!/bin/bash

# reset_branch.sh TARGET         (assumes source to be pre-release)
# OR
# reset_branch.sh --to TARGET    (assumes source to be pre-release)
# OR
# reset_branch.sh --from SOURCE --to TARGET

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

sleep 1
echo ""
echo "Press Ctrl+C within 5s to cancel..."

sleep 5

echo ""
(
git checkout "$source_branch" && 
git pull origin "$source_branch" && 
(git branch -D "$dest_branch" &>/dev/null || true) &&
git checkout "$dest_branch"
) || (
  echo "something went wrong while switching branches!" && exit 1
)

commits_since_last_reset=$(git log --boundary --right-only --oneline pre-release...HEAD | grep -o -P '(?<=branch).*(?= into)' | uniq -u 2>&1)
git reset --hard "$source_branch"

supTempFileAdd=$(touch delete.me && echo "$(date)" > delete.me && git add delete.me)

COMMIT_SUBJ="Resetting $dest_branch from $source_branch"
COMMIT_LOST_DATA="Commits from these branches could be lost:
> ${commits_since_last_reset:-none}"
COMMIT_MSG="$COMMIT_SUBJ via reset_branch.sh. $COMMIT_LOST_DATA"

(git commit -m "$COMMIT_MSG" && git push origin $dest_branch --force) || (echo "something went wrong while pushing!" && exit 0)

repoName=$(basename `git rev-parse --show-toplevel`)

# fetches all the branches of the repo
# delete any local branches whose remote counterpart is deleted
# (helps in case we change the API key)
sup_fetch=$(git fetch --all --prune 2>&1)

# filter the branches and get the one containing the API key
secretPrefix="tern/secrets/mailgun/"
secretSuffix="/end"
secretBranch=$(git branch -a | grep $secretPrefix | xargs)
mgApiKey=$(echo "$secretBranch" | grep -o -P "(?<=$secretPrefix).*(?=$secretSuffix)")

curGitUser=$(git config user.email)

supMailer=$(curl -s --user "api:$mgApiKey" \
  	https://api.eu.mailgun.net/v3/mg.tern-group.com/messages \
  	-F from='Chugli.ai <chugal.kishore@mg.tern-group.com>' \
  	-F to=squad-backend-aaaal75qw57nltfnpd5ipeaenu@terngroup.slack.com \
  	-F to=squad-frontend-aaaalmsqdekphutvjpqmqmqnwu@terngroup.slack.com \
  	-F subject="$repoName: '$dest_branch' branch reset from '$source_branch' by $curGitUser" \
  	-F text="$COMMIT_LOST_DATA")
  	# -F to=akshay.rao@tern-group.com \