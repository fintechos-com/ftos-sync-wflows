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

# Convert EXCLUDED_REPOS to an array (comma-separated values)
IFS=',' read -r -a EXCLUDED_REPO_ARRAY <<< "$EXCLUDED_REPOS"

IFS=',' read -r -a IGNORED_FILES_ARRAY <<< "$IGNORE_YAML_FILES"

export GH_TOKEN_MASTER
export GH_TOKEN_SLAVES
export ORG_MASTER
export ORG_SLAVES
export TEMPLATE_REPO
export PAGE=${PAGE:-1}  # Default to 1 if PAGE is not provided
export EXCLUDED_REPO_ARRAY
export IGNORED_FILES_ARRAY

# ✅ Log Environment Variables (Debugging)
echo "🔹 GH_TOKEN_MASTER: [SET]"
echo "🔹 GH_TOKEN_SLAVES: [SET]"
echo "🔹 ORG_MASTER: $ORG_MASTER"
echo "🔹 ORG_SLAVES: $ORG_SLAVES"
echo "🔹 TEMPLATE_REPO: $TEMPLATE_REPO"
echo "🔹 PAGE: $PAGE"
echo "🔹 EXCLUDED_REPOS: ${EXCLUDED_REPO_ARRAY[*]}"
echo "🔹 IGNORED_FILES: ${IGNORED_FILES_ARRAY[*]}"