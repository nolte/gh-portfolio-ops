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

Local, git-ignored values:

- `terraform/portfolio-ops/terraform.tfvars` → `project_number = 5`
  (the board at `https://github.com/users/nolte/projects/5`).
- `terraform/repos/terraform.tfvars` → the `gh-portfolio-ops` repository block
  (visibility `public`, default branch `develop`, the ruleset above).

## The PAT (minted by hand, then fed to Terraform)

The `MERGE_QUEUE_TOKEN` secret holds a personal access token. Terraform stores
it, but cannot create it:

- **Type:** classic PAT (a fine-grained PAT cannot reach personal-account
  Projects V2).
- **Scopes:** `repo` + `project`.
- **Minted** in the GitHub UI only: *Settings → Developer settings → Personal
  access tokens*.
- **Stored** in gopass:
  `gopass insert internet/github.com/nolte/tokens/gh-portfolio-ops/merge-queue-pat`.
- **Fed** to Terraform as `TF_VAR_merge_queue_token` via
  `source scripts/portfolio-ops-env.sh` (which also exports `GITHUB_TOKEN` from
  `gh auth token`), and lands on the repository as the `MERGE_QUEUE_TOKEN` secret.

## Manual / UI-only (cannot be managed as code)

GitHub offers no Terraform resource or API for these — they are one-time UI steps:

- **Creating the Projects V2 board** — `gh project create --owner nolte --title "PR Merge Queue"` (the `integrations/github` provider has no resource for user-level Projects V2).
- **Board views** — the table grouped by `Repository` and the kanban grouped by `Status` are configured in the board UI.
- **The built-in *Auto-archive items* workflow** — enabled in the board UI so merged and closed pull requests leave the board automatically.

## Enable sequence

1. Mint the PAT and store it in gopass (see above).
2. In `terraform-github-bootstrap`, set `project_number = 5` in
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
