#!/bin/bash
set -e

echo "Fetching repositories from organization '$ORG_SLAVES' starting from page $PAGE..."

PER_PAGE=100
ALL_REPOS=()

while :; do
  echo "Fetching page $PAGE..."
  
  REPO_PAGE=$(GH_TOKEN=$GH_TOKEN_SLAVES gh api "orgs/$ORG_SLAVES/repos?per_page=$PER_PAGE&page=$PAGE" --jq '.[] | {name: .name, owner: .owner.login}')

  if [[ -z "$REPO_PAGE" ]]; then
    echo "No more repositories found. Exiting pagination loop."
    break
  fi

  while read -r REPO_JSON; do
    ALL_REPOS+=("$REPO_JSON")
  done < <(echo "$REPO_PAGE")

  ((PAGE++))
done

echo "Total repositories fetched: ${#ALL_REPOS[@]}"
SELECTED_REPOS=()

for REPO_JSON in "${ALL_REPOS[@]}"; do
  REPO_NAME=$(echo "$REPO_JSON" | jq -r '.name')

  # Skip excluded repositories
  if [[ " ${EXCLUDED_REPO_ARRAY[@]} " =~ " ${REPO_NAME} " ]]; then
    echo "🚫 Skipping excluded repository: $REPO_NAME"
    continue
  fi

  TEMPLATE_NAME=$(GH_TOKEN=$GH_TOKEN_SLAVES gh api "repos/$ORG_SLAVES/$REPO_NAME" --jq '.template_repository.name // empty')

  if [[ "$TEMPLATE_NAME" == "$TEMPLATE_REPO" ]]; then
    SELECTED_REPOS+=("$REPO_NAME")
  fi
done

echo "${SELECTED_REPOS[@]}" > selected_repos.txt
