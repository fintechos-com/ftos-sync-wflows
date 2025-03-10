#!/bin/bash
set -e

if [[ ! -f updated_repos.txt ]]; then
  exit 0
fi

while IFS=',' read -r REPO UNIQUE_BRANCH; do
  GH_TOKEN=$GH_TOKEN_SLAVES gh pr create --title "Sync workflows from template" \
                 --body "Updating workflows from template repository" \
                 --base main \
                 --head "$UNIQUE_BRANCH" \
                 --label "sync-workflows"
done < updated_repos.txt

rm updated_repos.txt
