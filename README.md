# gh-portfolio-ops

Operational automations over the `nolte/*` GitHub portfolio. A sibling to
[`gh-plumbing`](https://github.com/nolte/gh-plumbing) (per-repo Probot config):
this repo hosts scheduled/dispatch **jobs** that act across the whole portfolio.

Each concern is one workflow under `.github/workflows/` plus its script under
`scripts/`. Repo-level Actions variables and secrets for these jobs are owned by
Terraform in
[`terraform-github-bootstrap`](https://github.com/nolte/terraform-github-bootstrap)
(`terraform/portfolio-ops/`), never set by hand here.

## Concerns

### PR merge-queue board (`merge-queue-sync`)

A kanban board over **all open pull requests** across `nolte/*`, plus a
scheduled reconcile: drag a card into **Done** and the linked PR gets the
`automerge` label — which hands it to the `gh-plumbing` automerge workflow that
squash-merges it once every required check is green.

Each run:
1. Adds every open `nolte/*` PR to the board (idempotent).
2. Reads each card's `Status`; for every card in **Done** whose PR is still
   open, applies the `automerge` label.

| Knob | Where | Meaning |
|---|---|---|
| `PROJECT_NUMBER` | repo variable (Terraform) | the board's number |
| `MERGE_QUEUE_TOKEN` | repo secret (Terraform, value from gopass) | PAT with `repo` + `project` |
| `DONE_OPTION` | env (default `Done`) | Status option that triggers the label |
| `LABEL` | env (default `automerge`) | label applied to PRs in Done |

**Why a cron, not a webhook:** `nolte` is a personal user account. Projects-V2
webhook events (`projects_v2_item`, "card moved") are **organisation-only**, and
GitHub Actions has no `on: projects_v2_item` trigger. So board state is
reconciled by polling (`*/10 * * * *`) instead of reacting to events.

Caveats:
- Up to ~10–15 min lag between dropping a card in Done and the label appearing.
- The `automerge` label must exist in the target repo (it does in repos wired to
  `gh-plumbing`); PRs in repos without it are skipped with a log line.

## Setup

See [`bootstrap.sh`](./bootstrap.sh) — creates the board and this repo. The PAT
must be minted in the GitHub UI (`repo` + `project` scopes); neither Terraform
nor any API can create it.

## Adding a concern

1. Add `.github/workflows/<concern>.yml` + `scripts/<concern>.sh` here.
2. If it needs a variable/secret, add a `<concern>.tf` in
   `terraform/portfolio-ops/` and export any secret via
   `scripts/portfolio-ops-env.sh` (from gopass).
