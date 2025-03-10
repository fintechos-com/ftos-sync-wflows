#!/bin/bash
set -e

read -r -a SELECTED_REPOS < selected_repos.txt

if [[ ${#SELECTED_REPOS[@]} -eq 0 ]]; then
  exit 0
fi

GH_TOKEN=$GH_TOKEN_MASTER git clone https://github.com/$ORG_MASTER/$TEMPLATE_REPO.git template-repo

for REPO in "${SELECTED_REPOS[@]}"; do
  GH_TOKEN=$GH_TOKEN_SLAVES git clone https://github.com/$ORG_SLAVES/$REPO.git
  cd $REPO

  GH_TOKEN=$GH_TOKEN_SLAVES git fetch origin main
  UNIQUE_BRANCH="update-workflows-$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
  git checkout -b "$UNIQUE_BRANCH"
  mkdir -p .github/workflows/

  for FILE in ../template-repo/.github/workflows/*.yaml; do
    FILE_NAME=$(basename "$FILE")
    
    if [[ " ${IGNORED_FILES[@]} " =~ " ${FILE_NAME} " ]]; then
      continue
    fi

    cp -f "$FILE" .github/workflows/
  done

  if [[ -n $(git status --porcelain) ]]; then
    git add .github/workflows/
    git commit -m "Sync workflows from template"
    git push --force-with-lease origin "$UNIQUE_BRANCH"
    echo "$REPO,$UNIQUE_BRANCH" >> updated_repos.txt
  fi

  cd ..
  rm -rf $REPO
done
