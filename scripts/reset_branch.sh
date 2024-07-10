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
git checkout "$dest_branch"
git reset --hard "$source_branch"
git push -f origin "$dest_branch"