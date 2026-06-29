# Audiences — gh-portfolio-ops

<!--
Produced via the `audience-identify` skill, following
spec/project/audience-identification/.
Do not add audiences without first declaring the bounded context below.
-->

## Bounded context

- **What it is:** `gh-portfolio-ops` — an operations/automation repository (a
  sibling to `gh-plumbing`) that runs scheduled and dispatch jobs across the
  `nolte/*` GitHub portfolio. First concern: the PR merge-queue board sync
  (`scripts/merge-queue-sync.sh` + `.github/workflows/merge-queue-sync.yml`).
  Also hosts the `spec/` corpus (portfolio-board, merge-queue-automation,
  event-driven-merge-queue, view-design-principles, portfolio-views,
  unreleased-changes) and the MkDocs docs (en/de).
- **Boundaries:** the automations, their specs, and their docs live here;
  repo-level Actions variables/secrets are provisioned by Terraform.
- **Explicitly outside:** the target `nolte/*` repositories themselves,
  `gh-plumbing`'s Probot configuration, and the `terraform-github-bootstrap`
  repository.

## Audiences

Each entry: label, relationship category, interaction surface, expectation,
documentation `track`, open questions, `confirmed` / `assumed`, criticality.

Portfolio-baseline track defaults: `user` → `user-docs`; `contributor` /
`operator` / `release-manager` → `developer-docs`.

### Direct consumers

- **Portfolio overseer / board user** (`board-user`) — _category_: direct-consumer ·
  _surface_: the Projects V2 "PR Merge Queue" board, `README.md` ·
  _expects_: a single unified view of open PRs/issues across `nolte/*`, and that
  dragging a card to **Done** hands the PR to the release flow ·
  _track_: `developer-docs` · _status_: `assumed` · _criticality_: primary
  - Open questions: none

### Operators

- **Portfolio operator** (`operator`) — _category_: operator ·
  _surface_: the Configuration docs, `Taskfile.yml` (`task sync`), the
  `merge-queue-sync` workflow, the Terraform `portfolio-ops` module ·
  _expects_: to mint the PAT, provision variable + secret, enable
  `Auto-archive items`, and monitor the cron run ·
  _track_: `developer-docs` · _status_: `confirmed` · _criticality_: primary
  - Open questions: none

### Contributors / maintainers

- **Concern contributor** (`contributor`) — _category_: contributor ·
  _surface_: `scripts/`, `.github/workflows/`, `spec/`, `CLAUDE.md` ·
  _expects_: to add a new concern (workflow + script) and maintain the specs,
  following the one-concern-one-workflow-one-script convention ·
  _track_: `developer-docs` · _status_: `confirmed` · _criticality_: secondary
  - Open questions: none

### Governing parties

- **Portfolio standards** (`portfolio-standards`) — _category_: governing-party ·
  _surface_: the `spec/` corpus, `.github/settings.yml` `_extends`, the Terraform
  rulesets ·
  _expects_: the repo conforms to the portfolio branching model, rulesets, and
  conventions (gh-plumbing / claude-shared specs) ·
  _track_: `developer-docs` · _status_: `assumed` · _criticality_: peripheral
  - Open questions: none

### Indirect audiences

- **Release manager** (`release-manager`) — _category_: indirect ·
  _surface_: the `automerge` label that triggers the release flow in the target
  repository ·
  _expects_: the **Done** signal reliably starts the release only for genuinely
  finished PRs ·
  _track_: `developer-docs` · _status_: `assumed` · _criticality_: secondary
  - Open questions: none
- **Target repo maintainers** (`target-repo-maintainer`) — _category_: indirect ·
  _surface_: the `automerge` label applied to their `nolte/*` PRs ·
  _expects_: the label appears only on PRs that are actually ready ·
  _track_: `developer-docs` · _status_: `assumed` · _criticality_: peripheral
  - Open questions: none

### `user-docs` track

- **No audience maps to this track** — `gh-portfolio-ops` ships no end-user
  product; its overview and configuration documentation targets operators and
  contributors (`developer-docs`).

## Open questions (cross-cutting)

- none

## Revisit triggers

- A new concern that exposes an end-user-facing surface (would introduce a
  genuine `user-docs` audience).
- The portfolio moving to a GitHub Organisation (changes the operator/board
  interaction model and unlocks event-driven triggers).
- A second human operator or external contributor joining (re-validate the
  `assumed` tags and the criticality ranking).
