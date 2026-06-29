#!/usr/bin/env bash
#
# One-time bootstrap for the gh-portfolio-ops repo and its first concern, the
# PR merge-queue board: create the Projects V2 board, create the GitHub repo
# from this directory, and push it.
#
# Prerequisites:
#   gh auth refresh -s project   # token needs the `project` scope
#
set -euo pipefail

OWNER="nolte"
TITLE="PR Merge Queue"
REPO="${OWNER}/gh-portfolio-ops"

echo "==> Creating Projects V2 board '${TITLE}' ..."
PROJ_JSON=$(gh project create --owner "$OWNER" --title "$TITLE" --format json)
NUMBER=$(echo "$PROJ_JSON" | jq -r '.number')
URL=$(echo "$PROJ_JSON" | jq -r '.url')
echo "    created project #${NUMBER}: ${URL}"

echo "==> Status field options:"
gh project field-list "$NUMBER" --owner "$OWNER" --format json \
  | jq -r '.fields[] | select(.name=="Status") | .options[].name' \
  | sed 's/^/      - /' || echo "      (no Status field — add one with a 'Done' option in the UI)"

echo "==> Creating + pushing repo ${REPO} (default branch develop) ..."
git init -q -b develop
git add -A
git -c user.name=nolte -c user.email=nolte07@gmail.com commit -q -m "feat: gh-portfolio-ops with merge-queue board sync"
gh repo create "$REPO" --private --source=. --remote=origin --push

cat <<EOF

Done — board #${NUMBER} and repo ${REPO} are live.

The PROJECT_NUMBER variable and MERGE_QUEUE_TOKEN secret are NOT set here —
they are owned by Terraform in terraform-github-bootstrap. Next:

  1. Mint a PAT (classic: scopes 'repo' + 'project') and store it in gopass:
        gopass insert internet/github.com/nolte/tokens/gh-portfolio-ops/merge-queue-pat
  2. Record the board number for Terraform:
        echo 'project_number = ${NUMBER}' >> terraform/portfolio-ops/terraform.tfvars
  3. Provision the variable + secret on ${REPO}:
        source scripts/portfolio-ops-env.sh && task tf:apply:portfolio-ops
  4. Adopt the repo into the inventory (it is already listed in
     terraform/repos/terraform.tfvars), then apply the ruleset:
        terraform -chdir=terraform/repos import \\
          'github_repository.managed["gh-portfolio-ops"]' gh-portfolio-ops
        task tf:apply
  5. In the board UI (${URL}) add a 'Board' layout view grouped by Status
     so you get the Todo / In Progress / Done kanban columns.
  6. Trigger the first sync:
        gh workflow run "Merge Queue Sync" --repo ${REPO}
EOF
