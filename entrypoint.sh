#!/bin/bash
set -e

# Load environment variables
source /app/setup_env.sh

# Run the modular scripts
/app/setup_git.sh
/app/fetch_repos.sh
/app/sync_workflows.sh
/app/create_pr.sh
