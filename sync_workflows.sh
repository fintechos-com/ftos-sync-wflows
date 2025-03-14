#!/bin/bash
set -e

read -r -a SELECTED_REPOS < selected_repos.txt

if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  echo "No repositories selected. Exiting."
  exit 0
fi

echo "Cloning template repository '$TEMPLATE_REPO' from '$ORG_MASTER'..."

# ✅ Use `GIT_ASKPASS_MASTER` for cloning from ORG_MASTER
GIT_ASKPASS="$GIT_ASKPASS_MASTER" git clone https://github.com/$ORG_MASTER/$TEMPLATE_REPO.git template-repo || {
  echo "❌ Failed to clone template repository! Exiting."
  exit 1
}

for REPO in "${SELECTED_REPOS[@]}"; do
  echo "Processing $REPO..."

  # ✅ Use `GIT_ASKPASS_SLAVES` for cloning and pushing to ORG_SLAVES
  GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git clone https://github.com/$ORG_SLAVES/$REPO.git || {
    echo "❌ Failed to clone repository $REPO! Skipping..."
    continue
  }
  
  cd $REPO

  GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git fetch origin main
  UNIQUE_BRANCH="update-workflows-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
  git checkout -b "$UNIQUE_BRANCH"
  mkdir -p .github/workflows/

  for FILE in ../template-repo/.github/workflows/*.yaml; do
    FILE_NAME=$(basename "$FILE")
    
    if [[ " ${IGNORED_FILES[@]} " =~ " ${FILE_NAME} " ]]; then
      continue
    fi

    cp -f "$FILE" .github/workflows/
  done

  if [[ -n $(git status --porcelain) ]]; then
    git add .github/workflows/
    git commit -m "Sync workflows from template"
    GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git push --force-with-lease origin "$UNIQUE_BRANCH"
    echo "$REPO,$UNIQUE_BRANCH" >> updated_repos.txt
    

      LABEL_EXISTS=$(gh api "repos/$ORG_SLAVES/$REPO/labels" --jq '.[] | select(.name == "sync-workflows") | .name')

      # ✅ If the label does not exist, create it
      if [[ -z "$LABEL_EXISTS" ]]; then
        echo "⚠️ Label 'sync-workflows' not found in $REPO. Creating it..."
        gh api "repos/$ORG_SLAVES/$REPO/labels" \
          --method POST \
          --field name="sync-workflows" \
          --field color="0075ca" \
          --field description="Automatically synced workflow updates"
        echo "✅ Label 'sync-workflows' created in $REPO."
      else
        echo "✅ Label 'sync-workflows' already exists in $REPO."
      fi

      
      # ✅ Use `GIT_ASKPASS_SLAVES` to authenticate GitHub CLI
      GH_TOKEN=$GH_TOKEN_SLAVES gh pr create \
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

      # ✅ Remove repo only after PR creation is confirmed
      rm -rf $REPO
  else
    echo "✔️ No changes detected. Skipping PR creation."    
  fi

  cd ..

done
