#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$GH_TOKEN" || -z "$ORG" || -z "$TOPIC" ]]; then
  echo "Error: Required environment variables (GH_TOKEN, ORG, TOPIC) are not set. Exiting."
  exit 1
fi

echo "Fetching repositories with topic '$TOPIC' in organization '$ORG'..."

PAGE=1
PER_PAGE=100
ALL_REPOS=()

while :; do
  echo "Fetching page $PAGE..."
  
  # Fetch repositories with pagination
  REPOS=$(gh api "orgs/$ORG/repos?per_page=$PER_PAGE&page=$PAGE" --jq ".[] | select((.topics[]? | contains(\"$TOPIC\")) and (.is_template | not)) | .name")

  # Stop if no more repositories are found
  if [[ -z "$REPOS" ]]; then
    echo "No more repositories found. Exiting loop."
    break
  fi

  # Append repositories to the list
  ALL_REPOS+=($REPOS)
  
  # Move to the next page
  ((PAGE++))
done

# Check if we found any repositories
if [[ ${#ALL_REPOS[@]} -eq 0 ]]; then
  echo "No repositories found matching the criteria. Exiting."
  exit 0
fi

echo "Repositories found: ${ALL_REPOS[@]}"

# Loop through all found repositories and sync only .github/workflows/
for REPO in "${ALL_REPOS[@]}"; do
  echo "Processing $REPO..."

  # Clone repository
  git clone https://github.com/$ORG/$REPO.git
  cd $REPO

  # Create a new branch
  git checkout -b update-workflows

  # Copy only the .github/workflows/ directory
  rm -rf .github/workflows/
  cp -r ../template-repo/.github/workflows/ .github/workflows/

  # Commit changes
  git add .github/workflows/
  git commit -m "Sync workflows from template"
  git push origin update-workflows

  # Create a pull request with label
  gh pr create --title "Sync workflows from template" \
               --body "Updating workflows from template repository" \
               --base main \
               --head update-workflows \
               --label "sync-workflows"

  cd ..
  rm -rf $REPO
done

echo "Sync completed!"
