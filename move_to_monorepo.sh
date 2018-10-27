#!/bin/sh
# Creates a new monorepo by fusing multiple repositories

# Child repositories that are going to be fused
CHILDREN="repo_lib_a repo_lib_b"

# Name of the created monorepo
MONOREPO="monorepo"

# Exit in case of any error
set -e

# Be verbose
set -x

# create the monorepo
mkdir $MONOREPO
cd $MONOREPO
git init

# Create a first commit. A first commit is needed in order to be able to merge into master afterwards
echo "*~" >.placeholder
git add .placeholder
git commit -m "First commit"
git rm .placeholder
git commit -m "Remove placeholder file"

# Add remotes for all children
for repo in $CHILDREN; do
        git remote add "$repo" "git@github.com:path/${repo}.git"
done

# Fetch all child repositories
git fetch --all

# Checkout all the master branches of the child repositories
for repo in $CHILDREN; do
        git checkout -f -b "${repo}_master" "${repo}/master"
        # Rewrite history to move all repo files into a subdirectory
        export SUBDIRECTORY="${repo}"
        git filter-branch -f --index-filter '
    git ls-files -s | sed "s-\t-&${SUBDIRECTORY}/-" | GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && if [ -f "$GIT_INDEX_FILE.new" ]; then mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE"; fi' --
done

# Switch back to our master branch
git checkout -f master

# Merge all the repositories in our master branch.
for repo in $CHILDREN; do
        git merge --no-commit --allow-unrelated-histories "${repo}_master"

        git commit -a -m "Merge ${repo} in subdir"
done

# remove all child repo branches and remotes
for repo in $CHILDREN; do
        git branch -D "${repo}_master"
        git remote remove "${repo}"
done

# prune all history and do an aggressive gc
git reflog expire --expire=now --all && git gc --prune=now --aggressive
