# Portfolio Views — Audience-Oriented View Catalogue

Status: draft

## Context
This spec is the concrete instantiation of
[`view-design-principles`](../view-design-principles/en.md) for the `nolte/*`
portfolio. It binds the audiences and design heuristics to specific, named views
over the portfolio board (see [`portfolio-board`](../portfolio-board/en.md)) and
the GitHub-native surfaces (Projects views, Insights, Releases, Milestones,
labels, the docs site). Each view declares whom it serves, the question it
answers, its detail level, its presentation form, the GitHub surface it lives on,
its filter or configuration, and the information it deliberately excludes as
noise. The catalogue is the basis downstream automations target — which view a
synced field feeds, what a generated roadmap shows, where the `Done` → `automerge`
handoff is visible.

## Goals
- A single overview gives the maintainer a direct view of open issues and pull
  requests across all `nolte/*` repositories, split into purpose-built views
- Each audience reaches a view tuned to its information need, at the right detail
  level and in a fitting presentation form, without another audience's noise
- The internal working surfaces and the external communication surfaces stay
  consistent, the external ones a curated projection of the internal state
- The catalogue is stable enough that automations can target named views without
  re-deriving their shape

## Non-Goals
- The reusable audience, detail-level, and form model — owned by
  [`view-design-principles`](../view-design-principles/en.md)
- Board fields, cross-repo sync, and the `Done` → `automerge` automation — owned
  by [`portfolio-board`](../portfolio-board/en.md) and
  [`merge-queue-automation`](../merge-queue-automation/en.md)
- Release versioning and publication mechanics — owned by the `release-automation`
  and `branching-model` specs
- The internal shape of planning artefacts under `project/`

## Requirements

### View declaration contract
- Every view in the catalogue **MUST** declare: its **audience**, its **leading
  question**, its **primary detail level** (per the taxonomy in
  [`view-design-principles`](../view-design-principles/en.md)), its
  **presentation form**, the **GitHub surface** it lives on, its **filter or
  configuration**, and the **excluded noise**
- Every view **MUST** conform to the design principles in
  [`view-design-principles`](../view-design-principles/en.md): its form **MUST**
  fit its audience and detail level, and it **MUST** exclude the information that
  is noise for its audience

### View catalogue
The portfolio **MUST** provide at least the following views. The surface column
names where the view lives; several views are saved views on the single
Projects V2 board, others are separate GitHub surfaces.

- **Open pull requests by repository (table)** — audience: maintainer
  (operational). Question: what open pull requests exist across the portfolio,
  organised by project? Detail: item-level (deliberately *not* field-level).
  Form: table. Surface: the Projects V2 board's default table view (for example
  "View 1"). Configuration: **grouped by the `Repository` field**; the visible
  columns are limited to a **minimal set — `Repository`, `Title`, `Status`** —
  with every other field hidden; `Repository` is a dedicated, first-class field,
  kept visible and used for both grouping and sorting. Excludes: the dense
  metadata columns (assignees, labels, reviewers, dates, milestone) by default —
  they stay available on demand. This is the canonical tabular master view of the
  board
- **Daily development** — audience: maintainer (operational). Question: what is in
  progress and what is blocked? Detail: item-level. Form: Kanban board. Surface:
  Projects V2 board view grouped by `Status`. Filter: open items excluding
  dependency updates (`-label:dependencies`). **SHOULD** visibly mark blocked
  items. Excludes: roadmap dates, shipped releases, portfolio aggregates. Note:
  GitHub Projects has no native per-column WIP limit; the absence is an accepted
  limitation
- **Triage** — audience: maintainer (operational). Question: what is new and not
  yet classified? Detail: item-level. Form: table or a dedicated board column.
  Surface: Projects V2 view. Filter: recently added items with no `Status` (or no
  triage marker) set. Excludes: everything already triaged
- **Release management** — audience: maintainer (release). Question: what is ready
  to ship — go or no-go? Detail: item-level summarising toward aggregated. Form:
  table or board filtered to release-ready pull requests. Surface: Projects V2
  view. Filter: `is:pr is:open` with `Status` = the `Done` option. This is the
  view from which the [`merge-queue-automation`](../merge-queue-automation/en.md)
  `Done` → `automerge` handoff is driven. Excludes: backlog triage, individual
  work-in-progress, the dependency queue
- **Dependency updates** — audience: dependency-update reviewer. Question: which
  updates are safe and which need scrutiny? Detail: item-level, grouped. Form:
  table grouped by update type and risk. Surface: Projects V2 view. Filter:
  `label:dependencies` (or the mirrored `Class` = `dependency` field per
  [`portfolio-board`](../portfolio-board/en.md)). **SHOULD** group by major /
  minor / patch so high-risk updates stand out. Excludes: feature work, roadmap
- **Portfolio health** — audience: maintainer (portfolio / steering). Question:
  how is the portfolio doing overall? Detail: aggregated. Form: charts. Surface:
  Projects V2 Insights (burn-up, counts per repository). Excludes: single-item
  detail. Note: historical charts require GitHub Team/Enterprise, and only a
  burn-up chart is native — record this where the view is configured
- **Roadmap** — audience: end user / stakeholder (and the maintainer's own
  quarterly planning). Question: what is planned and what comes next? Detail:
  aggregated over time. Form: roadmap / timeline. Surface: Projects V2 roadmap
  layout, or a published roadmap. Configuration: outcome-framed themes at a coarse
  horizon (a Now / Next / Later structure, or quarter buckets). The view **MUST
  NOT** present hard date commitments by default, to avoid turning every date into
  a promise. Excludes: work-in-progress, triage, internal metrics
- **Contributor entry** — audience: external contributor. Question: what can I
  pick up? Detail: item-level, curated. Form: a filtered issue list. Surface: the
  repository's `good first issue` / `help wanted` labels and the GitHub
  `/contribute` page. Excludes: internal prioritisation, the release pipeline, the
  dependency queue
- **Release notes / changelog** — audience: end user (notes) and developer
  (changelog). Question: what shipped? Detail: aggregated on the level of meaning.
  Form: curated release notes layered over a complete changelog. Surface: GitHub
  Releases with release-drafter categories derived from Conventional-Commits
  labels (see `branching-model` and `release-automation`). Excludes: planned or
  in-progress work

### Table conventions
- A table view **MUST** default to a minimal column set and **MUST NOT** surface
  the full field catalogue; identity plus state is the default (`Repository`,
  `Title`, `Status`), and any further field is opt-in, honouring the
  progressive-disclosure limit in
  [`view-design-principles`](../view-design-principles/en.md)
- Where a table spans repositories, it **MUST** keep `Repository` as a dedicated,
  visible field and **SHOULD** group by it; `Repository` **MUST** be available as
  a sort key, so the maintainer can order the table by project

### Cross-surface consistency
- The external-facing views (roadmap, release notes) **MUST** be a curated
  projection of the internal state (board, changelog): the same themes and
  outcomes, reduced in detail — a layered single source, not two independent
  documents that can drift apart
- A view **MUST NOT** mix audiences: where the solo maintainer wears several
  roles, each role gets its own filtered view rather than one blended surface

## Acceptance Criteria
- [ ] A named view catalogue exists; each entry declares audience, leading question, primary detail level, presentation form, GitHub surface, filter/configuration, and excluded noise
- [ ] The **Open pull requests by repository** table is grouped by the `Repository` field, shows only the minimal columns `Repository`, `Title`, `Status`, and keeps `Repository` as a dedicated sort key; all other fields are hidden by default
- [ ] The **Daily development** view is item-level on a board and excludes dependency updates; the **Release management** view surfaces release-ready pull requests and is the surface from which `Done` → `automerge` is driven
- [ ] The **Dependency updates** view is grouped by update type/risk over the `dependencies` marker (or mirrored `Class` field)
- [ ] The **Portfolio health** view is aggregated via Insights; the **Roadmap** view is time-aggregated and presents no hard date commitments by default
- [ ] The **Contributor entry** view surfaces unassigned `good first issue` / `help wanted` issues
- [ ] The **Release notes / changelog** view is a layered curated projection — notes for users over a complete changelog for developers
- [ ] Every view conforms to [`view-design-principles`](../view-design-principles/en.md): a fitting form for its declared detail level, with the audience's noise excluded

## Open Questions
- Which views are realised as Projects V2 saved views on the one board, and which
  as separate surfaces (Insights, Releases, the docs site)? The board's saved
  views cannot span multiple projects, so a future split would fragment the
  single pane of glass.
- Should the **Roadmap** view use a Now / Next / Later structure or dated quarter
  buckets? The choice trades flexibility against the precision stakeholders may
  expect.
- Should the **Triage** state be a distinct `Status` option or a separate project
  field, given the `Status` field also drives the board columns and the
  `Done` → `automerge` handoff?

## References
- Persona information needs: UXPin, *Dashboard Design Principles*
  (<https://www.uxpin.com/studio/blog/dashboard-design-principles/>); GitHub Docs,
  *Finding ways to contribute*
  (<https://docs.github.com/en/get-started/exploring-projects-on-github/finding-ways-to-contribute-to-open-source-on-github>);
  GitHub Docs, *Managing pull requests for dependency updates*
  (<https://docs.github.com/en/code-security/dependabot/working-with-dependabot/managing-pull-requests-for-dependency-updates>)
- GitHub surfaces: *About insights for Projects*
  (<https://docs.github.com/en/issues/planning-and-tracking-with-projects/viewing-insights-from-your-project/about-insights-for-projects>);
  *Automatically generated release notes*
  (<https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes>);
  *Encouraging helpful contributions with labels*
  (<https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/encouraging-helpful-contributions-to-your-project-with-labels>)
- Roadmap and release communication: ProdPad, *Now-Next-Later Roadmap*
  (<https://www.prodpad.com/glossary/now-next-later-roadmap/>); Featurebase,
  *Changelog vs. Release Notes*
  (<https://www.featurebase.app/blog/changelog-vs-release-notes>); Keep a Changelog
  (<https://keepachangelog.com/en/1.1.0/>)
