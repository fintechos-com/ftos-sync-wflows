#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$GH_TOKEN" || -z "$ORG" || -z "$TOPIC" ]]; then
  echo "Error: Required environment variables (GH_TOKEN, ORG, TOPIC) are not set. Exiting."
  exit 1
fi

echo "Fetching repositories from organization '$ORG'..."

PAGE=1
PER_PAGE=100
ALL_REPOS=()

while :; do
  echo "Fetching page $PAGE..."
  
  # Fetch repositories for the page, returning only name, topics, and is_template status
  REPO_PAGE=$(gh api "orgs/$ORG/repos?per_page=$PER_PAGE&page=$PAGE" --jq '.[] | {name: .name, topics: .topics, is_template: .is_template}')

  # Stop if no repositories are returned
  if [[ -z "$REPO_PAGE" ]]; then
    echo "No more repositories found. Exiting pagination loop."
    break
  fi

  # Extract repository names from JSON and append them to the array
  while read -r REPO_JSON; do
    ALL_REPOS+=("$REPO_JSON")
  done < <(echo "$REPO_PAGE" | jq -c '.') # Process line by line to avoid array issues

  # Move to the next page
  ((PAGE++))
done

# Check the total number of repositories fetched
echo "Total repositories fetched: ${#ALL_REPOS[@]}"

# Filter repositories based on topic and is_template=false
SELECTED_REPOS=()
for REPO_JSON in "${ALL_REPOS[@]}"; do
  REPO_NAME=$(echo "$REPO_JSON" | jq -r '.name')
  TOPICS=$(echo "$REPO_JSON" | jq -r '.topics | join(",")')
  IS_TEMPLATE=$(echo "$REPO_JSON" | jq -r '.is_template')

  if [[ "$IS_TEMPLATE" == "false" && "$TOPICS" == *"$TOPIC"* ]]; then
    SELECTED_REPOS+=("$REPO_NAME")
  fi
done

# Check if any repositories matched the criteria
if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  echo "No repositories found with topic '$TOPIC' and is_template=false. Exiting."
  exit 0
fi

echo "Repositories selected for sync: ${#SELECTED_REPOS[@]}"
echo "${SELECTED_REPOS[@]}"

# Loop through filtered repositories and sync .github/workflows/
for REPO in "${SELECTED_REPOS[@]}"; do
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
