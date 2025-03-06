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
  
  # Fetch all repositories for the page
  REPO_PAGE=$(gh api "orgs/$ORG/repos?per_page=$PER_PAGE&page=$PAGE" --jq ".[] | {name: .name, topics: .topics, is_template: .is_template}")

  # Stop if no more repositories exist
  if [[ -z "$REPO_PAGE" ]]; then
    echo "No more repositories found. Exiting pagination loop."
    break
  fi

  # Append repositories from this page to the full list
  ALL_REPOS+=("$REPO_PAGE")

  # Move to the next page
  ((PAGE++))
done

echo "Total repositories fetched: ${#ALL_REPOS[@]}"

# Filter repositories based on topic and is_template=false
SELECTED_REPOS=()
for REPO in "${ALL_REPOS[@]}"; do
  REPO_NAME=$(echo "$REPO" | jq -r '.name')
  TOPICS=$(echo "$REPO" | jq -r '.topics | join(",")')
  IS_TEMPLATE=$(echo "$REPO" | jq -r '.is_template')

  if [[ "$IS_TEMPLATE" == "false" && "$TOPICS" == *"$TOPIC"* ]]; then
    SELECTED_REPOS+=("$REPO_NAME")
  fi
done

# Check if any repositories matched
if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  echo "No repositories found with topic '$TOPIC' and is_template=false. Exiting."
  exit 0
fi

echo "Repositories selected for sync: ${SELECTED_REPOS[@]}"

# Loop through filtered repositories and sync .github/workflows/
for REPO in "${SELECTED_REPOS[@]}"; do
  echo "Processing $REPO..."

  # Clone repository
