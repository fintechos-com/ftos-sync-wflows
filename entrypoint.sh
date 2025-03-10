#!/bin/bash
set -e

# Load environment variables
source /app/setup_env.sh
source /app/setup_git.sh

# Run the modular scripts
/app/fetch_repos.sh
/app/sync_workflows.sh
/app/create_pr.sh
