#!/bin/bash
set -e

# ✅ Convert CLOSE_PR_DAYS to an integer (default 30, 0 means close all immediately)
CLOSE_PR_DAYS=${CLOSE_PR_DAYS:-30}

echo "🔍 Searching for PRs with label 'sync-workflows' older than $CLOSE_PR_DAYS days in selected repositories of '$ORG_SLAVES'..."
echo "🟡 DRY_RUN mode: $DRY_RUN (No changes will be made if true)"

export GH_TOKEN="$GH_TOKEN_SLAVES"

# ✅ Read the correct repositories from `selected_repos.txt`
if [[ ! -f selected_repos.txt ]]; then
  echo "❌ Error: selected_repos.txt not found! Exiting."
  exit 1
fi

read -r -a SELECTED_REPOS < selected_repos.txt

for REPO in "${SELECTED_REPOS[@]}"; do
  echo "🔎 Checking repository: $REPO..."

  # ✅ Find PRs with label "sync-workflows"
  if [[ "$CLOSE_PR_DAYS" -eq 0 ]]; then
    # ✅ Close all PRs with label "sync-workflows" immediately
    PR_DATA=$(gh pr list --repo "$ORG_SLAVES/$REPO" --state open --json number,headRefName,labels --jq \
      '.[] | select(.labels[].name == "sync-workflows") | {number: .number, branch: .headRefName}')
  else
    # ✅ Close PRs older than CLOSE_PR_DAYS with label "sync-workflows"
    PR_DATA=$(gh pr list --repo "$ORG_SLAVES/$REPO" --state open --json number,headRefName,labels,createdAt --jq \
      ".[] | select(.labels[].name == \"sync-workflows\" and (now - (.createdAt | fromdate)) > ($CLOSE_PR_DAYS * 86400)) | {number: .number, branch: .headRefName}")
  fi

  if [[ -z "$PR_DATA" ]]; then
    echo "✅ No PRs to close in $REPO."
    continue
  fi

  echo "$PR_DATA" | jq -c '.' | while read -r PR; do
    PR_NUMBER=$(echo "$PR" | jq -r '.number')
    BRANCH_NAME=$(echo "$PR" | jq -r '.branch')

    if [[ -z "$PR_NUMBER" || -z "$BRANCH_NAME" ]]; then
      echo "⚠️ Skipping malformed PR data: $PR"
      continue
    fi

    echo "❌ Closing PR #$PR_NUMBER in $REPO (Label: sync-workflows, Days: $CLOSE_PR_DAYS)..."

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have closed PR #$PR_NUMBER in $REPO"
    else
      gh pr close "$PR_NUMBER" --repo "$ORG_SLAVES/$REPO" --comment "This PR is being auto-closed after $CLOSE_PR_DAYS days as part of workflow maintenance."
    fi

    echo "🗑️ Deleting branch $BRANCH_NAME in $REPO..."

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "🟡 [DRY_RUN] Would have deleted branch $BRANCH_NAME in $REPO"
    else
      gh api -X DELETE "repos/$ORG_SLAVES/$REPO/git/refs/heads/$BRANCH_NAME" || {
        echo "⚠️ Failed to delete branch $BRANCH_NAME in $REPO. It may have been deleted manually."
      }
    fi
  done
done

echo "✅ PR cleanup complete."
