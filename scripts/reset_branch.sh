#!/bin/bash

# reset_branch --from pre-release --to demo
# reset_branch --from pre-release --to development

#Read the argument values
while [[ "$#" -gt 0 ]]
  do
    case $1 in
      -f|--from) source_branch="$2"; shift;;
      -t|--to) dest_branch="$2"; shift;;
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
git checkout "$source_branch"
git pull origin "$source_branch"
git branch -D "$dest_branch"
git checkout "$dest_branch"
commits_since_last_reset=$(git log --boundary --right-only --oneline pre-release...HEAD | grep -o -P '(?<=branch).*(?= into)' | uniq -u 2>&1)
git reset --hard "$source_branch"

touch delete.me
echo "$(date)" > delete.me
git add delete.me

git commit -m "Resetting $dest_branch from $source_branch via reset_branch.sh. Commits from these branches could be lost:
> ${commits_since_last_reset:-none}" -n

git push -f origin "$dest_branch"
