#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$GH_TOKEN" || -z "$ORG" || -z "$TEMPLATE_REPO" ]]; then
  echo "Error: Required environment variables (GH_TOKEN, ORG, TEMPLATE_REPO) are not set. Exiting."
  exit 1
fi

# Convert IGNORE_YAML_FILES to an array (comma-separated values)
IFS=',' read -r -a IGNORED_FILES <<< "$IGNORE_YAML_FILES"

echo "Fetching repositories from organization '$ORG'..."

PAGE=9
PER_PAGE=100
ALL_REPOS=()

# Retrieve all repositories in the organization (pagination)
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

# Check which repositories were created from the correct template
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

# Ensure at least one repository matched
if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  echo "No repositories found matching template '$TEMPLATE_REPO'. Exiting."
  exit 0
fi

echo "Repositories selected for sync: ${#SELECTED_REPOS[@]}"
echo "${SELECTED_REPOS[@]}"

# ✅ Set up GitHub authentication using GIT_ASKPASS
echo "Configuring Git authentication..."
export GIT_ASKPASS=$(mktemp)
chmod +x "$GIT_ASKPASS"
echo "#!/bin/bash" > "$GIT_ASKPASS"
echo "echo \"$GH_TOKEN\"" >> "$GIT_ASKPASS"

# Clone the template repository
echo "Cloning template repository '$TEMPLATE_REPO'..."
git clone https://github.com/$ORG/$TEMPLATE_REPO.git template-repo

# Sync workflows in selected repositories
for REPO in "${SELECTED_REPOS[@]}"; do
  echo "Processing $REPO..."

  # Clone repository using authentication
  git clone https://github.com/$ORG/$REPO.git
  cd $REPO

  # Create a new branch for the update
  git checkout -b update-workflows

  # Ensure the target workflows directory exists
  mkdir -p .github/workflows/

  # ✅ Copy files from template, skipping ignored files
  echo "Syncing workflows from template while ignoring: ${IGNORED_FILES[*]}"
  for FILE in ../template-repo/.github/workflows/*.yaml; do
    FILE_NAME=$(basename "$FILE")
    
    # Check if the file should be ignored
    if [[ " ${IGNORED_FILES[@]} " =~ " ${FILE_NAME} " ]]; then
      echo "Skipping $FILE_NAME..."
      continue
    fi

    echo "Copying $FILE_NAME..."
    cp -f "$FILE" .github/workflows/
  done

  # ✅ Check if there are actual changes before committing
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
                 --label "sync-workflows-new"
  else
    echo "No changes detected. Skipping PR creation."
  fi

  cd ..
  rm -rf $REPO
done

echo "Sync completed!"
