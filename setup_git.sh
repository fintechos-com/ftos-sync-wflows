#!/bin/bash
set -e

echo "Configuring Git authentication..."

# 🔥 Set up `GIT_ASKPASS` for GH_TOKEN_MASTER (ORG_MASTER)
echo "Setting up authentication for ORG_MASTER..."
export GIT_ASKPASS_MASTER=$(mktemp)
chmod +x "$GIT_ASKPASS_MASTER"
echo "#!/bin/bash" > "$GIT_ASKPASS_MASTER"
echo "echo \"$GH_TOKEN_MASTER\"" >> "$GIT_ASKPASS_MASTER"

# 🔥 Set up `GIT_ASKPASS` for GH_TOKEN_SLAVES (ORG_SLAVES)
echo "Setting up authentication for ORG_SLAVES..."
export GIT_ASKPASS_SLAVES=$(mktemp)
chmod +x "$GIT_ASKPASS_SLAVES"
echo "#!/bin/bash" > "$GIT_ASKPASS_SLAVES"
echo "echo \"$GH_TOKEN_SLAVES\"" >> "$GIT_ASKPASS_SLAVES"

# ✅ Configure Git to use token authentication
git config --global credential.helper ""
git config --global user.email "github-actions@github.com"
git config --global user.name "GitHub Actions Bot"

echo "Git authentication setup complete."
