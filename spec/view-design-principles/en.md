# View Design Principles — Audience, Detail Level, and Presentation Form

Status: draft

## Context
A software portfolio is surfaced through many representations: a Kanban board, a
dense table, a roadmap, charts, activity feeds, release notes, a documentation
site. Each representation serves a different audience with a different
information need, at a different level of detail. Without a shared model, views
accrete ad hoc: detail levels get mixed, a representation is chosen by habit
rather than fit, and one audience is shown another audience's noise.

This spec defines the reusable design model that every concrete view builds on:
the audiences and their information needs, a detail-level taxonomy, the fitness
profile of each presentation form, and the heuristics that decide which detail
level and form a given view must use. It is grounded in established
information-design literature (see References) and is the foundation the concrete
view catalogue [`portfolio-views`](../portfolio-views/en.md) and any
audience-facing documentation rest on. It consumes — and does not restate — the
general audience-identification methodology (`audience-identification` spec).

## Goals
- Every view declares whom it serves, so audience is an explicit design input
  rather than an afterthought
- A single detail-level taxonomy (aggregated / item-level / field-level) is
  applied consistently across all representations
- Form follows purpose: each presentation form has a documented fitness profile,
  so a view's representation is chosen by fit, not habit
- A small set of design heuristics keeps every view glanceable, audience-scoped,
  and free of the other audiences' noise

## Non-Goals
- The concrete named views of this portfolio — owned by
  [`portfolio-views`](../portfolio-views/en.md)
- Board fields, sync, and the `Done` → `automerge` automation — owned by
  [`portfolio-board`](../portfolio-board/en.md) and
  [`merge-queue-automation`](../merge-queue-automation/en.md)
- The general methodology for identifying audiences — owned by the
  `audience-identification` spec; this spec applies it to the view-design domain

## Requirements

### Audience model
- **MUST** define the audiences a view can serve; each audience **MUST** be
  characterised by its primary question, the information that is *signal* for it,
  and the information that is *noise* and therefore excluded
- **MUST** cover at least these audiences:
  - **Maintainer — operational (daily development):** "What am I working on, and
    what is blocked?" Signal: work-in-progress, blocked items, untriaged new
    issues. Noise: roadmap dates, shipped releases, portfolio aggregates
  - **Maintainer — release management:** "What is ready to ship — go or no-go?"
    Signal: release-ready pull requests, open defects, check status and trend.
    Noise: backlog triage, individual work-in-progress, the dependency queue
  - **Maintainer — portfolio overview / steering:** "How is the portfolio doing
    overall?" Signal: aggregate counts, trends, and health across repositories.
    Noise: single-item detail
  - **Dependency-update reviewer:** "Which updates are safe, and which need
    scrutiny?" Signal: dependency pull requests grouped by update type and risk,
    changelogs, breaking-change flags. Noise: the feature backlog, the roadmap
  - **External contributor:** "What can I pick up, and what is the status of my
    pull request?" Signal: unassigned `good first issue` / `help wanted` issues,
    project activity and responsiveness, the status of one's own pull request.
    Noise: internal prioritisation, the release pipeline, the dependency queue
  - **End user / stakeholder:** "What is planned, and what shipped?" Signal:
    roadmap themes at a coarse horizon, release notes. Noise: work-in-progress,
    triage, internal metrics
- **MUST** treat the solo maintainer as wearing several of these roles at once:
  the same person needs a differently-filtered view per role, because what is
  signal in one role is noise in another

### Detail-level taxonomy
- **MUST** classify every view by exactly one *primary* detail level:
  - **aggregated** — counts, distributions, and trends over many items (KPI level)
  - **item-level** — one card or row per issue or pull request (work-unit level)
  - **field-level** — many metadata fields per item visible at once (attribute level)
- A view **MAY** make a deeper level reachable on demand, but its *primary* level
  is the one it presents first and the one it is classified by

### Design principles (every view MUST satisfy)
- **Purpose determines density:** the view's leading question is defined first;
  the detail level follows from it (a goal overview is aggregated/strategic, a
  live work view is focused/operational, a root-cause view is dense/analytical).
  Detail level is not a free choice — it is derived from purpose (three-dashboard
  typology, Few / Eckerson)
- **Overview first, details on demand:** a view starts at the highest sensible
  aggregation and makes deeper levels reachable through zoom, filter, and
  drill-down — never by showing every level at once (Shneiderman's
  information-seeking mantra)
- **Progressive disclosure, at most two levels:** the primary surface shows the
  frequently-needed information, a secondary surface holds the rare; more than
  two disclosure levels disorients, so deeper analysis belongs in its own
  dedicated view rather than a third drill-down (Nielsen Norman Group)
- **Signal versus noise per audience:** a view **MUST** exclude the information
  that is noise for its audience; filtering is a deliberate act of omission that
  increases comprehensibility, not a loss (Shneiderman)
- **At a glance for top-level views:** strategic and operational overviews
  **MUST** be graspable with minimal interaction and cognitive load, favouring a
  small number of preattentively-encoded signals (roughly five to nine) over
  information volume (Nielsen Norman Group)

### Presentation-form fitness profile
- **MUST** maintain a fitness profile that maps each presentation form to its
  purpose, typical detail level, audience fit, and limits. At minimum:

  | Form | Primary detail level | Leading question | Audience fit | Key limit |
  |---|---|---|---|---|
  | Kanban board | item-level (status) | What is in progress / blocked? | Maintainer, operational | Weak at field comparison and time; needs WIP discipline |
  | Table | field-level (dense) | Compare, filter, act in bulk | Maintainer, planning/triage | No flow/time semantics; density needs clean design |
  | Roadmap / Timeline | aggregated (time) | When does what arrive? | Stakeholder; own quarterly planning | Needs maintained date/iteration fields; rigid to re-prioritisation |
  | Charts / Insights | aggregated (KPI) | How is it doing overall? | Steering/overview; shareable | History needs Team/Enterprise; only burn-up natively |
  | Lists / Feeds | item-level (chronological) | What happened recently? | Anyone following along | No aggregation/priority; firehose at scale |
  | Release notes / Changelog | aggregated (meaning) | What shipped? | External users / developers | Documents only what shipped, not plans |

- A view **MUST** pick a form whose fitness matches its audience and primary
  detail level. A mismatch — dense field-level data forced onto a board, or
  daily task steering pushed onto a roadmap — is drift and **MUST** be flagged

## Acceptance Criteria
- [ ] An audience model enumerates the personas above, each with a primary question, its signal, and its excluded noise
- [ ] A detail-level taxonomy (aggregated / item-level / field-level) is defined, and every view classifies into exactly one primary level
- [ ] The design principles (purpose→density, overview-first, progressive-disclosure with at most two levels, signal-vs-noise, at-a-glance) are stated and required of every view
- [ ] A presentation-form fitness profile maps each form to purpose, detail level, audience fit, and limits
- [ ] A view that uses a form mismatched to its audience or primary detail level is identified as drift
- [ ] The model cites its sources (Shneiderman; Nielsen Norman Group on progressive disclosure and dashboards; the Few / Eckerson three-dashboard typology)

## Open Questions
- Should the audience model be derived per repository via the
  `audience-identification` methodology, or is one portfolio-level model
  sufficient for the view-design domain?
- Where the platform lacks a capability a principle assumes (for example WIP
  limits on a board, or native burn-down charts), should the spec record the gap
  as an accepted limitation or mandate a workaround?

## References
- Ben Shneiderman, *The Eyes Have It: A Task by Data Type Taxonomy for
  Information Visualizations* (1996) — "Overview first, zoom and filter, then
  details-on-demand". <https://www.cs.umd.edu/~ben/papers/Shneiderman1996eyes.pdf>
  (wording corroborated via <https://infovis-wiki.net/wiki/Visual_Information-Seeking_Mantra>)
- Nielsen Norman Group, *Progressive Disclosure*.
  <https://www.nngroup.com/articles/progressive-disclosure/>
- Nielsen Norman Group, *Dashboards: Making Charts and Graphs Easier to
  Understand*. <https://www.nngroup.com/articles/dashboards-preattentive/>
- The three-dashboard typology (strategic / operational / analytical), after
  Stephen Few and Wayne Eckerson.
  <https://www.idashboards.com/operational-analytical-and-strategic-the-three-types-of-dashboards/>
- GitHub Docs, *Changing the layout of a view* (Board / Table / Roadmap).
  <https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/changing-the-layout-of-a-view>
