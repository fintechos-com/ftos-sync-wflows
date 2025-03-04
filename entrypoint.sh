#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$GH_TOKEN" || -z "$ORG" || -z "$TEMPLATE_REPO" ]]; then
  echo "Error: Required environment variables (GH_TOKEN, ORG, TEMPLATE_REPO) are not set. Exiting."
  exit 1
fi

echo "Fetching repositories created from template '$TEMPLATE_REPO' in organization '$ORG'..."
REPOS=$(gh api "orgs/$ORG/repos?per_page=100" --jq ".[] | select(.template_repository.name==\"$TEMPLATE_REPO\") | .name")

if [[ -z "$REPOS" ]]; then
  echo "No repositories found. Exiting."
  exit 0
fi

echo "Repositories found:"
echo "$REPOS"

git clone https://github.com/$ORG/$TEMPLATE_REPO.git template-repo

for REPO in $REPOS; do
  echo "Processing $REPO..."

  git clone https://github.com/$ORG/$REPO.git
  cd $REPO
  git checkout -b update-workflows

  rm -rf .github/workflows/
  cp -r ../template-repo/.github/workflows/ .github/workflows/

  git add .github/workflows/
  git commit -m "Sync workflows from template"
  git push origin update-workflows

  gh pr create --title "Sync workflows from template" \
               --body "Updating workflows from template repository" \
               --base main \
               --head update-workflows \
               --label "ftos-sync-wflow"

  cd ..
  rm -rf $REPO
done

echo "Sync completed!"
