# 🚀 Sync Workflows from Template GitHub Action

## 📘 Overview
This GitHub Action **syncs only the `.github/workflows/` folder** from a **template repository** across multiple repositories in an organization.

- ✅ **Propagates changes via Pull Requests (PRs)** instead of committing directly.
- ✅ **Updates an existing PR instead of creating duplicates.**
- ✅ **Supports repository exclusion to prevent unintended updates.**
- ✅ **Allows ignoring specific workflow files.**
- ✅ **Includes an optional feature to automatically close stale PRs.**
- ✅ **Supports `DRY_RUN` mode for testing without making changes.**

---

## 📋 Inputs & Configuration

### 🔧 Inputs Table

| Input Name        | Required | Default | Description |
|------------------|----------|---------|-------------|
| `GH_TOKEN_MASTER` | ✅ Yes | `N/A` | GitHub Token for the template repository (**Org Master**). |
| `ORG_MASTER` | ✅ Yes | `N/A` | Organization where the **template repository** exists. |
| `TEMPLATE_REPO` | ✅ Yes | `N/A` | Name of the template repository containing workflows. |
| `GH_TOKEN_SLAVES` | ❌ No | Same as `GH_TOKEN_MASTER` | GitHub Token for the target repositories (**Org Slaves**). |
| `ORG_SLAVES` | ❌ No | Same as `ORG_MASTER` | Organization where the **child repositories** are located. |
| `EXCLUDED_REPOS` | ❌ No | `""` | Comma-separated list of repositories **to exclude** from syncing. |
| `IGNORE_YAML_FILES` | ❌ No | `""` | Comma-separated list of workflow files **to ignore** during sync. |
| `PAGE` | ❌ No | `1` | Page number to start fetching repositories from (pagination). |
| `CLOSE_PR` | ❌ No | `"false"` | If `"true"`, closes stale PRs instead of syncing workflows. |
| `CLOSE_PR_DAYS` | ❌ No | `30` | Number of days before a PR is considered stale and closed. |
| `DRY_RUN` | ❌ No | `"false"` | If `"true"`, simulates the action **without making changes**. |

---

## 🔄 Features

- 🏗 **Propagates workflow changes** from a template repository to multiple repositories.
- 🔄 **Updates existing PRs instead of creating duplicates.**
- 🔖 **Labels PRs with `"sync-workflows"`** for easy tracking.
- 📂 **Syncs only `.github/workflows/`** while ignoring specified files.
- 🚫 **Supports repository exclusion** to prevent unintended changes.
- 🛑 **Auto-closes stale PRs** after a set number of days.
- 🟡 **Supports `DRY_RUN` mode** to preview actions before execution.

---

## 🚀 Usage Example

```yaml
name: Sync Workflows
on:
  workflow_dispatch:  # Manual trigger

jobs:
  sync_workflows:
    runs-on: ubuntu-latest
    steps:
      - name: Run Workflow Sync Action
        uses: fintechos-com/ftos-sync-wflows@main
        with:
          GH_TOKEN_MASTER: ${{ secrets.GH_MASTER_TOKEN }}
          ORG_MASTER: fintechos-com
          TEMPLATE_REPO: cs-delivery-project-template
          GH_TOKEN_SLAVES: ${{ secrets.GH_SLAVE_TOKEN }}
          ORG_SLAVES: ftos-external
          EXCLUDED_REPOS: "delivery-hwdhackathon,delivery-cec-cecbankml24"
          IGNORE_YAML_FILES: "master-slave-workflow-sync.yaml"
          PAGE: 1
          CLOSE_PR: "false"
          CLOSE_PR_DAYS: 30
          DRY_RUN: "false"
