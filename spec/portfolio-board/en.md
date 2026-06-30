# Portfolio Board — Unified Cross-Repository View

Status: draft

## Context
A single maintainer operates many repositories under one personal GitHub account
(`nolte/*`). Without a unified view, open issues and pull requests are scattered
across dozens of repositories and there is no single place to see what needs
attention, what is in flight, and what is ready to ship. This spec defines a
single GitHub Projects V2 board that aggregates open issues and pull requests
across the portfolio and presents them through purpose-built views — one for
daily development, one for release management — with a clear, filterable
separation between real requirements (features, fixes, issues) and dependency
updates produced by Renovate and Dependabot.

GitHub Projects V2 is the substrate: a project exists at the user level, holds
items from multiple repositories, and renders them as Table, Board, or Roadmap
layouts across any number of saved views. The mechanics of *populating* the
board and *acting* on board state are governed by the sibling spec
[`merge-queue-automation`](../merge-queue-automation/en.md); this spec defines
the board's shape, fields, and views only.

## Goals
- One unified Projects V2 board gives the maintainer a direct overview of open
  issues and pull requests across all `nolte/*` repositories
- Daily-development work and release management each have a dedicated saved view
  in the same project, so the day-to-day surface and the shipping surface never
  bleed into each other
- Real requirements are separated from dependency-update pull requests by a
  uniform, filterable marker, so the maintainer can focus on one class at a time
- The board model is a stable foundation that downstream automations
  (cross-repo sync, `Done` → `automerge`) build on without re-deriving structure

## Non-Goals
- The automation that fills the board and reacts to the `Done` column — owned by
  [`merge-queue-automation`](../merge-queue-automation/en.md)
- Per-repository branching and release mechanics — owned by the `branching-model`
  and `release-automation` specs
- Organisation-level Projects features (this portfolio is a personal account)
- The internal shape of the planning artefacts under `project/` — owned by the
  `roadmap`, `sprint`, and `feature` specs

## Requirements

### Project substrate
- **MUST** use a single GitHub Projects V2 project as the unified portfolio
  board, owned by the `noltarium` organisation (the source repositories stay
  under the `nolte/*` user account; an org project can track their pull requests)
- **MUST** aggregate open issues and open pull requests from across the
  `nolte/*` repositories into that one project
- **MUST NOT** rely on the built-in auto-add workflow as the sole population
  mechanism: on the Free and Pro plans the number of auto-add workflows is
  capped (Free permits one, i.e. a single source repository per project), which
  is insufficient for a multi-repository portfolio. Cross-repository population
  is therefore delegated to the sync automation defined in
  [`merge-queue-automation`](../merge-queue-automation/en.md)

### Status field and board layout
- **MUST** define a Single-Select `Status` field whose options include at least
  `Todo`, `In Progress`, and `Done`; the Board layout's columns map to this
  field, and dragging a card between columns updates the item's `Status`
- **MUST** treat the `Done` option as the semantic trigger for release handoff;
  its label text is configurable but **MUST** be declared and kept stable,
  because the automation reads it by name

### Requirement vs. dependency separation
- **MUST** distinguish *requirement* items (features, fixes, documentation,
  issues) from *dependency-update* pull requests opened by Renovate or Dependabot
- **MUST** treat the `dependencies` label as the canonical marker for a
  dependency-update pull request
- **MUST** ensure the marker is uniform across the portfolio: Dependabot applies
  `dependencies` automatically, but Renovate does not unless configured, so every
  repository's Renovate configuration **MUST** emit a `dependencies` label (via
  the portfolio preset's `labels`/`addLabels`, see the `project-structure`
  Renovate preset) so label-based separation is reliable
- **MUST** keep bot authorship (`renovate[bot]`, `dependabot[bot]`) available as
  a fallback signal for classifying a pull request when the label is absent
- **MUST**, when board grouping by class is required, provide a Single-Select
  project field (for example `Class` with options `requirement` and `dependency`)
  that mirrors the dependency marker onto the project item, because Projects V2
  cannot group a board by a repository label; the mirroring write is performed by
  the sync automation

### Views
- **MUST** provide a **Daily development** saved view: Board layout, grouped by
  `Status`, filtered to open items and excluding dependency updates
  (`-label:dependencies`, or `Class` ≠ `dependency` where the mirror field is used)
- **MUST** provide a **Release management** saved view: filtered to
  `is:pr is:open`, surfacing pull requests in the `Done` / ready-to-release state
- **SHOULD** provide a **Dependency updates** saved view filtered to
  `label:dependencies` (or `Class` = `dependency`) so dependency churn is
  triaged separately from feature work
- **SHOULD** use an Insights chart for an aggregate cross-repository health view
  (open vs. closed over time, items per repository)

### Filter semantics
- View filters **MUST** stay within Projects V2's supported semantics: any
  qualifier may be negated with a leading `-`; multiple values of the same field
  are combined with logical OR; there is **no** logical OR across different
  fields. Views **MUST NOT** be designed assuming cross-field OR

## Acceptance Criteria
- [ ] A single Projects V2 project owned by the `noltarium` organisation aggregates open issues and pull requests across `nolte/*` repositories
- [ ] A Single-Select `Status` field exists with `Todo`, `In Progress`, and a stable `Done` option
- [ ] Dependency-update pull requests carry the `dependencies` label uniformly (Dependabot default plus the Renovate preset emitting it)
- [ ] A **Daily development** view excludes dependency updates; a **Release management** view surfaces release-ready pull requests
- [ ] When board grouping by class is used, a Single-Select project field mirrors the requirement/dependency class onto each item
- [ ] Every view filter relies only on supported semantics (negation and same-field OR; no cross-field OR)

## Open Questions
- What is the exact plan tier of the `nolte` account? It determines whether the
  built-in auto-add is usable at all and how many source repositories it could
  cover before the API-based sync becomes mandatory.
- As the repository count grows, is one shared project still the right unit, or
  should concerns be split across projects? Native cross-project aggregation
  (a roadmap or query spanning multiple projects) is not supported, so a split
  would fragment the single pane of glass.
