#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$GH_TOKEN" || -z "$ORG" || -z "$TEMPLATE_REPO" ]]; then
  echo "Error: Required environment variables (GH_TOKEN, ORG, TEMPLATE_REPO) are not set. Exiting."
  exit 1
fi

echo "Fetching repositories from organization '$ORG'..."

PAGE=1
PER_PAGE=100
ALL_REPOS=()

# Step 1: Retrieve all repositories in the organization (pagination)
while :; do
  echo "Fetching page $PAGE..."
  
  # Fetch repositories for the page (basic details)
  REPO_PAGE=$(gh api "orgs/$ORG/repos?per_page=$PER_PAGE&page=$PAGE" --jq '.[] | {name: .name, owner: .owner.login}')

  # Stop if no repositories are returned
  if [[ -z "$REPO_PAGE" ]]; then
    echo "No more repositories found. Exiting pagination loop."
    break
  fi

  # Append repositories from this page to the array
  while read -r REPO_JSON; do
    ALL_REPOS+=("$REPO_JSON")
  done < <(echo "$REPO_PAGE")

  # Move to the next page
  ((PAGE++))
done

# Step 2: Check which repositories were created from the correct template
echo "Total repositories fetched: ${#ALL_REPOS[@]}"
SELECTED_REPOS=()

for REPO_JSON in "${ALL_REPOS[@]}"; do
  REPO_NAME=$(echo "$REPO_JSON" | jq -r '.name')
  OWNER_NAME=$(echo "$REPO_JSON" | jq -r '.owner')

  echo "Checking repository '$OWNER_NAME/$REPO_NAME'..."

  # Fetch full repository details
  TEMPLATE_NAME=$(gh api "repos/$OWNER_NAME/$REPO_NAME" --jq '.template_repository.name // empty')

  if [[ "$TEMPLATE_NAME" == "$TEMPLATE_REPO" ]]; then
    echo "✅ Matched template: $REPO_NAME (Template: $TEMPLATE_NAME)"
    SELECTED_REPOS+=("$REPO_NAME")
  else
    echo "❌ Skipping: $REPO_NAME (Template: $TEMPLATE_NAME)"
  fi
done

# Step 3: Ensure at least one repository matched
if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  echo "No repositories found matching template '$TEMPLATE_REPO'. Exiting."
  exit 0
fi

echo "Repositories selected for sync: ${#SELECTED_REPOS[@]}"
echo "${SELECTED_REPOS[@]}"

# Step 4: Clone the template repository
echo "Cloning template repository '$TEMPLATE_REPO'..."
git clone https://github.com/$ORG/$TEMPLATE_REPO.git template-repo

# Step 5: Sync only `.github/workflows/` in selected repositories
for REPO in "${SELECTED_REPOS[@]}"; do
  echo "Processing $REPO..."

  # Clone repository
  git clone https://github.com/$ORG/$REPO.git
  cd $REPO

  # Create a new branch for the update
  git checkout -b update-workflows

  # Ensure the target workflows directory exists
  mkdir -p .github/workflows/

  # Copy files from template without deleting extra YAMLs
  echo "Syncing workflows from template..."
  cp -rf ../template-repo/.github/workflows/* .github/workflows/

  # Check if there are changes
  if [[ -n $(git status --porcelain) ]]; then
    echo "Changes detected, committing update..."

    # Commit and push changes
    git add .github/workflows/
    git commit -m "Sync workflows from template"
    git push origin update-workflows

    # Create a pull request with label
    gh pr create --title "Sync workflows from template" \
                 --body "Updating workflows from template repository" \
                 --base main \
                 --head update-workflows \
                 --label "sync-workflows"
  else
    echo "No changes detected. Skipping PR creation."
  fi

  cd ..
  rm -rf $REPO
done

echo "Sync completed!"
