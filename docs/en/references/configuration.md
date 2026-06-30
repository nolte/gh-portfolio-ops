---
title: Configuration
audience: [operator]
content_mode: reference
track: developer-docs
last_updated: 2026-06-29
---

# Configuration

The merge-queue automation needs a small set of inputs. Most are managed as code
in [`terraform-github-bootstrap`](https://github.com/nolte/terraform-github-bootstrap);
a few are inherently manual because GitHub exposes no API or Terraform resource
for them.

## Managed by Terraform (IaC)

These are provisioned by `terraform-github-bootstrap` and **must not** be set by
hand on the repository:

| Configuration | Terraform resource | Module |
|---|---|---|
| `PROJECT_NUMBER` (Actions **variable**) | `github_actions_variable` | `terraform/portfolio-ops/merge-queue.tf` |
| `MERGE_QUEUE_TOKEN` (Actions **secret**) | `github_actions_secret` | `terraform/portfolio-ops/merge-queue.tf` |
| Repository (`description`, `visibility`, `has_*`) | `github_repository` | `terraform/repos` |
| `develop` branch protection ruleset (require a PR, require the `check` status check, linear history, block force-pushes and deletions) | `github_repository_ruleset` | `terraform/repos` |
| `PORTFOLIO_APP_ID` (Actions **variable**) | `github_actions_variable` (portfolio-app module) | `terraform/portfolio-app` |
| `PORTFOLIO_APP_PRIVATE_KEY` (Actions **secret**) | `github_actions_secret` (portfolio-app module) | `terraform/portfolio-app` |

Local, git-ignored values:

- `terraform/portfolio-ops/terraform.tfvars` → `project_number = 1`
  (the board at `https://github.com/orgs/noltarium/projects/1`). The board lives
  under the **noltarium** organisation; the workflows set `PROJECT_OWNER=noltarium`
  while the source repositories stay under `nolte/*` (`REPO_OWNER=nolte`). The
  same classic PAT works because `nolte` is an org admin.
- `terraform/repos/terraform.tfvars` → the `gh-portfolio-ops` repository block
  (visibility `public`, default branch `develop`, the ruleset above).
- `terraform/portfolio-app/terraform.tfvars` → `gh-portfolio-ops` listed in
  `consumer_repositories`, so it receives the portfolio-App variable and secret.

### Portfolio GitHub App credentials

`PORTFOLIO_APP_ID` and `PORTFOLIO_APP_PRIVATE_KEY` carry the `nolte-portfolio-app`
credentials that the `automerge` and `release-publish` workflows use to mint a
short-lived installation token. The `terraform/portfolio-app` module provisions
them onto every repository in its `consumer_repositories` list; the App ID, slug,
and private key come from gopass
(`internet/github.com/nolte/apps/nolte-portfolio-app/{appid,slug,private_key}`)
via `source scripts/portfolio-app-env.sh && task tf:apply:portfolio-app`.

!!! warning "App installation is a separate prerequisite"
    Provisioning only places the credentials. Minting the token also requires the
    **`nolte-portfolio-app` GitHub App to be installed on this repository** (repo
    access granted). Without the installation, `automerge` and `release-publish`
    fail at runtime even with the variable and secret present. Verify under
    *Settings → Installations → nolte-portfolio-app → Repository access*.

## The PAT (minted by hand, then fed to Terraform)

The `MERGE_QUEUE_TOKEN` secret holds a personal access token. Terraform stores
it, but cannot create it:

- **Type:** classic PAT — a fine-grained PAT cannot reach personal-account
  Projects V2.
- **Required scopes** — tick exactly these two top-level checkboxes under
  *Settings → Developer settings → Personal access tokens → Tokens (classic)*:

  | Scope | Why the sync needs it |
  |---|---|
  | `repo` (full) | Apply the `automerge` label to pull requests across every `nolte/*` repository — private ones included — via `POST /repos/{owner}/{repo}/issues/{n}/labels`, and read the open pull requests to reconcile the board. |
  | `project` | Read and write the user-level Projects V2 board: add items, read each item's `Status`, and delete items from archived repositories. Ticking `project` also includes `read:project`. |

  No other scopes are required — do not grant `admin:*`, `workflow`, or
  `delete_repo`.
- **Minted** in the GitHub UI only.
- **Stored** in gopass:
  `gopass insert internet/github.com/nolte/tokens/gh-portfolio-ops/merge-queue-pat`.
- **Fed** to Terraform as `TF_VAR_merge_queue_token` via
  `source scripts/portfolio-ops-env.sh` (which also exports `GITHUB_TOKEN` from
  `gh auth token`), and lands on the repository as the `MERGE_QUEUE_TOKEN` secret.

## Manual / UI-only (cannot be managed as code)

GitHub offers no Terraform resource or API for these — they are one-time UI steps:

- **Creating the Projects V2 board** — `gh project create --owner noltarium --title "PR Merge Queue"` (the `integrations/github` provider has no resource for Projects V2). The board is org-owned; an org project can still track pull requests from the personal `nolte/*` repositories.
- **Board views** — the table grouped by `Repository` and the kanban grouped by `Status` are configured in the board UI.
- **The built-in *Auto-archive items* workflow** — enabled in the board UI so merged and closed pull requests leave the board automatically.

## Enable sequence

1. Mint the PAT and store it in gopass (see above).
2. In `terraform-github-bootstrap`, set `project_number = 1` (the noltarium board) in
   `terraform/portfolio-ops/terraform.tfvars` (local, git-ignored).
3. Adopt the existing repository into Terraform state before the first apply:
   `terraform -chdir=terraform/repos import 'github_repository.managed["gh-portfolio-ops"]' gh-portfolio-ops`
4. Apply the repository + ruleset, then the portfolio-ops variable + secret:
   `task tf:apply` and `source scripts/portfolio-ops-env.sh && task tf:apply:portfolio-ops`.
5. In the board UI, enable the **Auto-archive items** workflow.
6. Smoke-test: `gh workflow run "Merge Queue Sync" --repo nolte/gh-portfolio-ops`.
   The `*/10` cron then takes over.

The contract behind each input is specified under `spec/` — see
`merge-queue-automation` (token scopes, board hygiene) and `portfolio-board`
(the board model).
