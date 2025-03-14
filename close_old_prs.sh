#!/bin/bash
set -e

# ✅ Convert CLOSE_PR_DAYS to an integer (default 30, 0 means close all immediately)
CLOSE_PR_DAYS=${CLOSE_PR_DAYS:-30}

echo "🔍 Searching for PRs with label 'sync-workflows' older than $CLOSE_PR_DAYS days in organization '$ORG_SLAVES'..."
echo "🟡 DRY_RUN mode: $DRY_RUN (No changes will be made if true)"

export GH_TOKEN="$GH_TOKEN_SLAVES"

# ✅ Fetch all repositories in ORG_SLAVES
REPO_LIST=$(gh repo list "$ORG_SLAVES" --json name --jq '.[].name')

for REPO in $REPO_LIST; do
  echo "🔎 Checking repository: $REPO..."

  # ✅ Find PRs with label "sync-workflows"
  if [[ "$CLOSE_PR_DAYS" -eq 0 ]]; then
    PR_DATA=$(gh pr list --repo "$ORG_SLAVES/$REPO" --state open --json number,headRefName,labels --jq \
      '.[] | select(.labels[].name == "sync-workflows") | {number: .number, branch: .headRefName}')
  else
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
