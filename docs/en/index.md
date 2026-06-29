# gh-portfolio-ops

Operational automation over the `nolte/*` GitHub portfolio. Sibling to
[`gh-plumbing`](https://github.com/nolte/gh-plumbing) (per-repo Probot config):
this repository hosts scheduled and dispatch **jobs** that act across the whole
portfolio.

Each concern is one workflow under `.github/workflows/` plus its script under
`scripts/`. Repo-level Actions variables and secrets are owned by Terraform in
[`terraform-github-bootstrap`](https://github.com/nolte/terraform-github-bootstrap)
(`terraform/portfolio-ops/`), never set by hand here.

## Concerns

### PR merge-queue board (`merge-queue-sync`)

A kanban board over all open pull requests across `nolte/*`, plus a scheduled
reconcile: drag a card into **Done** and the linked PR gets the `automerge`
label, which hands it to the `gh-plumbing` automerge workflow.
