#!/bin/bash
set -e

# Load environment variables
source /app/setup_env.sh
source /app/setup_git.sh

# Run the modular scripts
/app/fetch_repos.sh
if [[ "$CLOSE_PR" == "true" ]]; then
  echo "🔄 Closing PRs older than $CLOSE_PR_DAYS days..."
  /app/close_old_prs.sh
else
  echo "🔄 Syncing workflows..."
  /app/sync_workflows.sh
fi
#/app/create_pr.sh
