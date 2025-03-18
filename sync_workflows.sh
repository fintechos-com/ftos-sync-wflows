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
# ✅ Trust the GitHub Actions workspace directory
git config --global --add safe.directory /github/workspace
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
  export GH_TOKEN="$GH_TOKEN_SLAVES"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🟡 [DRY_RUN] Would have cloned repository: $REPO"
  else
    GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git clone https://github.com/$ORG_SLAVES/$REPO.git || {
      echo "❌ Failed to clone repository $REPO! Skipping..."
      continue
    }
    cd "$REPO"
  fi

  # ✅ Get the latest open PR branch (sorting by newest)
  EXISTING_PR_BRANCH=$(gh pr list --repo "$ORG_SLAVES/$REPO" --state open --json headRefName,createdAt,labels \
    --jq "[.[] | select(.labels[].name == \"sync-workflows\")] | sort_by(.createdAt) | reverse | .[0].headRefName")

  if [[ -n "$EXISTING_PR_BRANCH" ]]; then
    echo "⚠️ Found an existing open PR with branch '$EXISTING_PR_BRANCH' in $REPO."
    UNIQUE_BRANCH="$EXISTING_PR_BRANCH"

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have switched to existing PR branch '$EXISTING_PR_BRANCH'."
    else
      git checkout "$EXISTING_PR_BRANCH"
    fi
  else
    UNIQUE_BRANCH="update-workflows-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have created and switched to new branch: $UNIQUE_BRANCH."
    else
      git checkout -b "$UNIQUE_BRANCH"
    fi
  fi

  mkdir -p .github/workflows/

  echo "Checking ignored YAML files..."
  # ✅ Ensure the template repository has workflows before copying
  if [[ ! -d "../template-repo/.github/workflows" || -z "$(ls -A ../template-repo/.github/workflows/*.{yaml,yml} 2>/dev/null)" ]]; then
    echo "❌ No workflow files (.yaml or .yml) found in template repository. Skipping sync for $REPO."
    if [[ "$DRY_RUN" != "true" ]]; then
      cd ..
      rm -rf "$REPO"
    fi
    continue
  fi

  for FILE in ../template-repo/.github/workflows/*.{yaml,yml}; do
    [[ -e "$FILE" ]] || continue  # Skip if no matching files exist
  
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

      # ✅ If a PR exists, force-push to update the PR
      if [[ -n "$EXISTING_PR_BRANCH" ]]; then
        echo "🔄 Updating existing PR with branch '$EXISTING_PR_BRANCH'..."
        #git push --force-with-lease origin "$EXISTING_PR_BRANCH"
        GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git push --force-with-lease "https://$GH_TOKEN_SLAVES@github.com/$ORG_SLAVES/$REPO.git" "$EXISTING_PR_BRANCH"
      else
        echo "🚀 Creating a new branch and pushing changes."
        #git push --force-with-lease origin "$UNIQUE_BRANCH"
        GIT_ASKPASS="$GIT_ASKPASS_SLAVES" git push --force-with-lease "https://$GH_TOKEN_SLAVES@github.com/$ORG_SLAVES/$REPO.git" "$UNIQUE_BRANCH"
      fi
    fi
  else
    echo "✔️ No changes detected in $REPO. Skipping PR update."
    if [[ "$DRY_RUN" != "true" ]]; then
      cd ..
      rm -rf "$REPO"
    fi
    continue
  fi

  # ✅ If a PR already exists, skip PR creation
  if [[ -n "$EXISTING_PR_BRANCH" ]]; then
    echo "✅ PR for branch '$EXISTING_PR_BRANCH' is already open. Updated the branch."
    continue
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
