#!/bin/bash
set -e

if [[ ! -f updated_repos.txt ]]; then
  exit 0
fi

while IFS=',' read -r REPO UNIQUE_BRANCH; do

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
  GH_TOKEN=$GH_TOKEN_SLAVES gh pr create --title "Sync workflows from template" \
                 --body "Updating workflows from template repository" \
                 --base main \
                 --head "$UNIQUE_BRANCH" \
                 --label "sync-workflows"
done < updated_repos.txt

rm updated_repos.txt
