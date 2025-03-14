#!/bin/bash
set -e

# Ensure required environment variables are set
if [[ -z "$GH_TOKEN_MASTER" || -z "$ORG_MASTER" || -z "$TEMPLATE_REPO" ]]; then
  echo "Error: Required environment variables (GH_TOKEN_MASTER, ORG_MASTER, TEMPLATE_REPO) are not set. Exiting."
  exit 1
fi

# If GH_TOKEN_SLAVES is not set or empty, use GH_TOKEN_MASTER
if [[ -z "$GH_TOKEN_SLAVES" ]]; then
  echo "GH_TOKEN_SLAVES not provided, using GH_TOKEN_MASTER."
  export GH_TOKEN_SLAVES="$GH_TOKEN_MASTER"
  export ORG_SLAVES="$ORG_MASTER"
fi

# ✅ Convert EXCLUDED_REPOS & IGNORE_YAML_FILES to space-separated strings
export EXCLUDED_REPO_STRING=$(echo "$EXCLUDED_REPOS" | tr ',' ' ')
export IGNORED_FILES_STRING=$(echo "$IGNORE_YAML_FILES" | tr ',' ' ')

export GH_TOKEN_MASTER
export GH_TOKEN_SLAVES
export ORG_MASTER
export ORG_SLAVES
export TEMPLATE_REPO
export PAGE=${PAGE:-1}  # Default to 1 if PAGE is not provided
export EXCLUDED_REPO_STRING
export IGNORED_FILES_STRING

# ✅ Log Environment Variables (Debugging)
echo "🔹 GH_TOKEN_MASTER: [SET]"
echo "🔹 GH_TOKEN_SLAVES: [SET]"
echo "🔹 ORG_MASTER: $ORG_MASTER"
echo "🔹 ORG_SLAVES: $ORG_SLAVES"
echo "🔹 TEMPLATE_REPO: $TEMPLATE_REPO"
echo "🔹 PAGE: $PAGE"
echo "🔹 Excluded Repositories: $EXCLUDED_REPO_STRING"
echo "🔹 Ignored Files: $IGNORED_FILES_STRING"