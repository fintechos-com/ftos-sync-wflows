#!/bin/bash
set -e

# ✅ Convert space-separated strings back to arrays
read -r -a EXCLUDED_REPO_ARRAY <<< "$EXCLUDED_REPO_STRING"
read -r -a IGNORED_FILES_ARRAY <<< "$IGNORED_FILES_STRING"

# ✅ Log Environment Variables for Debugging
echo "🔹 GH_TOKEN_SLAVES: [SET]"
echo "🔹 ORG_SLAVES: $ORG_SLAVES"
echo "🔹 TEMPLATE_REPO: $TEMPLATE_REPO"
echo "🔹 PAGE: $PAGE"
echo "🔹 Excluded Repositories: ${EXCLUDED_REPO_ARRAY[*]}"
echo "🔹 Ignored Files: ${IGNORED_FILES_ARRAY[*]}"
echo "🟡 DRY_RUN mode: $DRY_RUN (No changes will be made if true)"

read -r -a SELECTED_REPOS < selected_repos.txt

if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  echo "No repositories selected. Exiting."
  exit 0
fi

echo "Cloning template repository '$TEMPLATE_REPO' from '$ORG_MASTER'..."

if [[ "$DRY_RUN" == "true" ]]; then
  echo "🟡 [DRY_RUN] Would have cloned template repository: $TEMPLATE_REPO"
else
  GIT_ASKPASS="$GIT_ASKPASS_MASTER" git clone https://github.com/$ORG_MASTER/$TEMPLATE_REPO.git template-repo || {
    echo "❌ Failed to clone template repository! Exiting."
    exit 1
  }
fi

for REPO in "${SELECTED_REPOS[@]}"; do
  if [[ " ${EXCLUDED_REPO_ARRAY[@]} " =~ " ${REPO} " ]]; then
    echo "🚫 Skipping excluded repository: $REPO"
    continue
  fi
  echo "Processing $REPO..."

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🟡 [DRY_RUN] Would have cloned repository: $REPO"
  else
    GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git clone https://github.com/$ORG_SLAVES/$REPO.git || {
      echo "❌ Failed to clone repository $REPO! Skipping..."
      continue
    }
    cd "$REPO"
  fi

  UNIQUE_BRANCH="update-workflows-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🟡 [DRY_RUN] Would have created and switched to branch: $UNIQUE_BRANCH"
  else
    GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git fetch origin main
    git checkout -b "$UNIQUE_BRANCH"
  fi

  mkdir -p .github/workflows/

  echo "Checking ignored YAML files..."
  for FILE in ../template-repo/.github/workflows/*.yaml; do
    FILE_NAME=$(basename "$FILE")
    echo "Comparing $FILE_NAME with ignored files: ${IGNORED_FILES_ARRAY[*]}"

    if [[ " ${IGNORED_FILES_ARRAY[@]} " =~ " ${FILE_NAME} " ]]; then
      echo "🚫 Skipping ignored file: $FILE_NAME"
      continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have copied file: $FILE_NAME"
    else
      cp -f "$FILE" .github/workflows/
    fi
  done

  if [[ -n $(git status --porcelain) ]]; then
    echo "🔄 Changes detected. Committing and pushing..."

    for IGNORE_FILE in "${IGNORED_FILES_ARRAY[@]}"; do
      if [[ -f ".github/workflows/$IGNORE_FILE" ]]; then
        echo "🚫 Removing ignored file before committing: $IGNORE_FILE"
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "🟡 [DRY_RUN] Would have removed file: $IGNORE_FILE"
        else
          git rm --cached ".github/workflows/$IGNORE_FILE"
        fi
      fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have committed and pushed updates."
    else
      git add .github/workflows/
      git commit -m "Sync workflows from template"
      GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git push --force-with-lease origin "$UNIQUE_BRANCH"
      echo "$REPO,$UNIQUE_BRANCH" >> ../updated_repos.txt
    fi
  else
    echo "✔️ No changes detected in $REPO. Skipping PR creation."
    if [[ "$DRY_RUN" != "true" ]]; then
      cd ..
      rm -rf "$REPO"
    fi
    continue
  fi

  export GH_TOKEN="$GH_TOKEN_SLAVES"

  echo "🔍 Checking if label 'sync-workflows' exists in $REPO..."
  LABEL_EXISTS=$(gh api "repos/$ORG_SLAVES/$REPO/labels" --jq '.[] | select(.name == "sync-workflows") | .name')

  if [[ -z "$LABEL_EXISTS" ]]; then
    echo "⚠️ Label 'sync-workflows' not found in $REPO. Creating it..."
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have created label 'sync-workflows' in $REPO"
    else
      gh api "repos/$ORG_SLAVES/$REPO/labels" \
        --method POST \
        --field name="sync-workflows" \
        --field color="0075ca" \
        --field description="Automatically synced workflow updates"
      echo "✅ Label 'sync-workflows' created in $REPO."
    fi
  else
    echo "✅ Label 'sync-workflows' already exists in $REPO."
  fi

  echo "🔄 Creating Pull Request for $REPO..."
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🟡 [DRY_RUN] Would have created PR for $REPO."
  else
    gh pr create \
      --repo "$ORG_SLAVES/$REPO" \
      --title "Sync workflows from template" \
      --body "Updating workflows from template repository.\n\nThis PR was automatically created by GitHub Actions." \
      --base main \
      --head "$UNIQUE_BRANCH" \
      --label "sync-workflows" || {
        echo "❌ Failed to create PR for $REPO. Check if the branch exists."
        continue
      }
    echo "✅ PR successfully created for $REPO!"
  fi

  if [[ "$DRY_RUN" != "true" ]]; then
    cd ..
    rm -rf "$REPO"
  fi
done

if [[ "$DRY_RUN" == "true" ]]; then
  echo "🟡 [DRY_RUN] Would have deleted updated_repos.txt"
else
  rm -f updated_repos.txt
fi
