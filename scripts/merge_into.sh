
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
    # echo "Invalid target branch: '$MERGE_INTO_BRANCH'"
    # echo "Only development and demo allowed"
    # echo "Try again."
    # exit
    # ;;
esac

# REPO_NAME=$(basename $(git rev-parse --show-toplevel))
CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)

suppress_git_fetch=$(git fetch origin 2>&1)

export LOCAL_CUR_BR=$CUR_BRANCH
export REMOTE_CUR_BR=origin/$CUR_BRANCH

if [ "$(git rev-parse "$LOCAL_CUR_BR")" == "$(git rev-parse "$REMOTE_CUR_BR")" ]
then
    echo ""
else
    echo ""
    echo "$CUR_BRANCH is NOT in sync with its remote branch."
    echo -e "Run\tgit pull origin $CUR_BRANCH"
    echo -e "-or-\tcommit/stash/discard the local changes..."
    echo -e "-or-\tgit push origin $CUR_BRANCH"
    echo "and rerun merge_into."
    exit 1
fi

echo "Starting the steps to send commits from $CUR_BRANCH to $MERGE_INTO_BRANCH..."
# sleep 1
# echo "                                          Press Ctrl + C to cancel..."
# sleep 5

echo "Switching to $MERGE_INTO_BRANCH..."
# echo "                                          Press Ctrl + C to cancel..."
# sleep 2
suppress_git_checkout=$(git checkout "$MERGE_INTO_BRANCH" 2>&1)
echo ""
# sleep 2

echo "Discarding all unpushed changes of your local $MERGE_INTO_BRANCH branch."
# echo "                                          Press Ctrl + C to cancel..."
# sleep 2
# echo "..."
# sleep 2
suppress_git_reset=$(git reset --hard "origin/$MERGE_INTO_BRANCH" 2>&1 && git clean -fd 2>&1)
echo ""

echo "Pulling latest $MERGE_INTO_BRANCH... from remote."
# echo "                                          Press Ctrl + C to cancel..."
# sleep 2
# echo "..."
# sleep 2
suppress_git_pull_target=$(git pull origin "$MERGE_INTO_BRANCH" 2>&1)
echo ""

echo "Running GIT MERGE $CUR_BRANCH --SQUASH"
# sleep 2
# echo "                                          Press Ctrl + C to cancel..."
# sleep 2
# echo "..."
suppress_git_merge_output=$(git merge "$CUR_BRANCH" --squash 2>&1)
# sleep 2
echo "$suppress_git_merge_output"

git status

echo ""
export AUTO_COMMIT_MSG="Merge branch '$CUR_BRANCH' into $MERGE_INTO_BRANCH via merge_into.sh"

if [[ "$suppress_git_merge_output" == *"Automatic merge went well"* ]]; then

  echo "~ ~ ~ ~ ~ ~ ~ ~ No conflicts! ~ ~ ~ ~ ~ ~ ~ ~"
  echo "Auto-committing!"
  git commit -m "$AUTO_COMMIT_MSG"
  
  # echo "Auto-commit done but not pushing automatically..."
  echo ""
  echo "PUSHING IT!!!"

  git push origin "$MERGE_INTO_BRANCH"
else
  echo "~ ~ ~ ~ ~ ~ ~ ~ Conflicts OMG ~ ~ ~ ~ ~ ~ ~ ~ "
  echo ""
  echo "Please resolve them, add a new commit and then push it to origin."
  echo ""
  echo "git commit -m \"$AUTO_COMMIT_MSG\"             <<<<----copy this for later"
  echo "and then, run"
  echo "git push origin $MERGE_INTO_BRANCH" 
fi
