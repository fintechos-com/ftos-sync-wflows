#!/bin/bash
set -e

# Run modular scripts
/app/setup_env.sh
/app/setup_git.sh
/app/fetch_repos.sh
/app/sync_workflows.sh
/app/create_pr.sh
