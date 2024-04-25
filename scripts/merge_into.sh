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

echo "Starting the steps to send commits from $CUR_BRANCH to $MERGE_INTO_BRANCH..."
sleep 1
echo "                                          Press Ctrl + C to cancel..."
sleep 5

echo "Switching to $MERGE_INTO_BRANCH..."
echo "                                          Press Ctrl + C to cancel..."
sleep 2
git checkout "$MERGE_INTO_BRANCH"
echo ""
sleep 2

echo "Discarding all unpushed changes of your local $MERGE_INTO_BRANCH branch."
echo "                                          Press Ctrl + C to cancel..."
sleep 2
echo "..."
sleep 2
git reset --hard && git clean -fd
echo ""

echo "Pulling latest $MERGE_INTO_BRANCH... from remote."
echo "                                          Press Ctrl + C to cancel..."
sleep 2
echo "..."
sleep 2
git pull origin "$MERGE_INTO_BRANCH"
echo ""

echo "Running GIT MERGE $CUR_BRANCH --SQUASH"
sleep 2
echo "                                          Press Ctrl + C to cancel..."
sleep 2
echo "..."
git merge "$CUR_BRANCH" --squash
sleep 2
echo ""

echo "Running GIT STATUS..."
sleep 1
git status

sleep 4

echo "-------------------------------------------------"
echo "Now, take a stock of these changes, resolve conflicts and add a new commit."
echo "Then push it to origin using:"
echo ""
echo "git push origin $MERGE_INTO_BRANCH"