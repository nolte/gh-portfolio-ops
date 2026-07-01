# Merge-Queue Automation — `Done` → `automerge`

Status: draft

## Context
The portfolio board (see [`portfolio-board`](../portfolio-board/en.md)) lets the
maintainer drag a pull-request card into the `Done` column to signal "ready to
ship". On a personal GitHub account there is no event-driven way to react to a
project-item move: the `projects_v2_item` webhook fires only for
organisation-owned projects, and GitHub Actions exposes no `on: projects_v2_item`
trigger. A scheduled poller therefore reconciles board state on an interval and,
for every pull request whose card sits in `Done`, applies the `automerge` label.
That label is the hand-off point: the target repository's automerge workflow
(from `nolte/gh-plumbing`) squash-merges the pull request once required checks
pass, which starts the release flow there.

This spec governs the automation's contract — its trigger model, authentication,
board population, the `Done` → `automerge` rule, and its observability and safety
properties. It does **not** define the board's views or fields (that is
[`portfolio-board`](../portfolio-board/en.md)) nor what `automerge` does
downstream (that is the gh-plumbing automerge workflow and the
`release-automation` spec).

## Goals
- Reliably translate "pull-request card in `Done`" into the `automerge` label on
  the corresponding pull request, within the constraints of a personal account
- Keep the board populated with the portfolio's open pull requests
- Operate without any event-driven project trigger, which does not exist for
  user-account projects
- Be idempotent, observable, and safe to run repeatedly on a short interval

## Non-Goals
- The board's view, field, and grouping model — owned by
  [`portfolio-board`](../portfolio-board/en.md)
- What happens after `automerge` is applied — owned by the gh-plumbing automerge
  workflow and the `release-automation` / `branching-model` specs
- Provisioning of the token and repository variables — owned by Terraform in
  `terraform-github-bootstrap` (`terraform/portfolio-ops/`)

## Requirements

### Trigger model
- **MUST** be driven by a scheduled (cron) GitHub Actions workflow; it **MUST
  NOT** depend on `projects_v2_item` webhooks or an `on: projects_v2_item`
  trigger, neither of which exists for user-account projects
- **SHOULD** use a cron interval no shorter than the platform floor of 5 minutes,
  and **MUST** treat board reconciliation as eventually-consistent: scheduled
  runs can be delayed under load and dropped at peak times, so real latency
  between dropping a card in `Done` and the label appearing is minutes, not
  real-time (a `*/10` interval is a reasonable default)
- **MUST** account for the platform rule that, in public repositories, scheduled
  workflows are automatically disabled after 60 days of repository inactivity;
  the repository **MUST** carry a mitigation (for example a keepalive dispatch or
  external monitoring) so the poller does not silently stop

### Authentication
- **MUST** authenticate with a classic personal access token carrying the
  `project` scope (read and write project data), the `repo` scope (to edit
  pull-request labels), and the `read:org` scope — the board is owned by the
  `noltarium` organisation, and without `read:org` the `gh project` CLI cannot
  classify the owner and fails with `unknown owner type`
- **MUST NOT** rely on a fine-grained personal access token for this workflow: the
  classic PAT is the supported path for the cross-owner setup (org-owned board,
  `nolte/*` source repositories)
- **MUST NOT** rely on a GitHub App installation token to read the project: the
  poller authenticates as the token-owning user, not as an App installation
- **MUST** read the token from a repository secret provisioned by Terraform
  (`terraform-github-bootstrap`); the token **MUST NOT** be committed

### Board population
- **MUST** add every open `nolte/*` pull request to the board idempotently —
  re-adding an existing item returns the existing item and is a no-op
- **SHOULD** mirror the requirement/dependency class onto the item's
  Single-Select project field when the board uses class grouping (per
  [`portfolio-board`](../portfolio-board/en.md))

### Board hygiene
- **MUST NOT** sync pull requests from archived repositories: filter them out at
  the source (`--archived=false`) and prune any board item whose repository is
  archived, because archived repositories are read-only and their open pull
  requests cannot be merged. Archived items are also excluded from
  `Done` → `automerge` labeling. The prune pass **MUST** collect across every page
  before deleting, so deletions do not shift the pagination cursor
- **SHOULD** enable the Projects built-in *Auto-archive items* workflow so that
  merged or closed pull requests drop off the active board automatically. The
  prune above covers archived *repositories*; merged and closed *items* are
  handled natively by this built-in workflow, not by this script, so the board
  does not accumulate shipped or abandoned pull requests

### `Done` → `automerge`
- **MUST** read each item's `Status` field and, for every item whose `Status`
  equals the configured `Done` option **and** whose pull request is still open,
  apply the `automerge` label
- **MUST** set the label through the GraphQL `addLabelsToLabelable` mutation or
  the equivalent REST endpoint (`POST /repos/{owner}/{repo}/issues/{n}/labels`),
  **never** through `updateProjectV2ItemFieldValue` (which can change only project
  fields, not the labels of the underlying issue or pull request) and **never**
  through `gh pr edit --add-label`, which queries the deprecated Projects-classic
  `projectCards` field and fails on accounts where Projects classic is sunset
- **MUST** be idempotent: applying `automerge` to a pull request that already
  carries it is a no-op, and the label is applied at most once per pull request
- **MUST** skip — with an explicit log line — any pull request in a repository
  where the `automerge` label does not exist, rather than failing the run
- **MUST NOT** merge the pull request itself; applying `automerge` hands off to
  the target repository's automerge workflow, which performs the squash-merge and
  thereby starts the release flow

### Observability and safety
- **MUST** log per-pull-request actions (added, labeled, skipped) and a run
  summary count
- **MUST** paginate the project-items query so runs cover more than 100 board
  items
- **MUST** document that Renovate keeps a pull request's labels in sync only
  until another account edits them: once this automation sets `automerge` on a
  Renovate pull request, Renovate stops making further label changes on that pull
  request — an acceptable but intentional side effect

## Acceptance Criteria
- [ ] A scheduled workflow (cron interval ≥ 5 minutes) reconciles the board; the automation relies on no project webhook or project event trigger
- [ ] Authentication uses a classic PAT with `project`, `repo`, and `read:org` scopes, sourced from a Terraform-provisioned repository secret, never committed
- [ ] Every open `nolte/*` pull request is added to the board idempotently
- [ ] Pull requests from archived repositories are neither added nor retained: the source query filters with `--archived=false` and a prune pass removes board items whose repository is archived
- [ ] The Projects built-in *Auto-archive items* workflow is enabled so merged/closed pull requests leave the active board without manual action
- [ ] Pull requests whose `Status` equals the configured `Done` option and that are still open receive the `automerge` label via `addLabelsToLabelable` or the equivalent REST endpoint (never `gh pr edit`)
- [ ] Labeling is idempotent and skips repositories lacking the `automerge` label with a log line
- [ ] The automation never merges pull requests directly; merge and release are delegated to the target repository's automerge workflow
- [ ] The project-items query is paginated to cover more than 100 items, and each run logs a summary
- [ ] The repository carries a mitigation for the 60-day scheduled-workflow disable on public repositories

## Open Questions
- What is the desired maximum latency between marking a card `Done` and the
  `automerge` label appearing? It drives the cron interval and whether polling
  alone is acceptable. Event-driven alternatives to the poll are catalogued in
  [`event-driven-merge-queue`](../event-driven-merge-queue/en.md).
- Should the board's built-in automation also set `Status` → `Done` on pull-request
  merge, so the column reflects merged state without a manual move, or is `Done`
  reserved strictly as a human "ready to ship" signal that precedes merge?
