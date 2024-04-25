#!/bin/bash

# reset_branch --from pre-release --to demo
# reset_branch --from pre-release --to development

#Read the argument values
while [[ "$#" -gt 0 ]]
  do
    case $1 in
      -f|--from) source_branch="$2"; shift;;
      -r|--to) dest_branch="$2"; shift;;
    esac
    shift
done



printf "This will reset the "$dest_branch" branch using the "$source_branch" branch..."

sleep 5

git checkout $source_branch
git pull origin $source_branch
git checkout $dest_branch
git reset --hard $source_branch
git push -f origin $dest_branch