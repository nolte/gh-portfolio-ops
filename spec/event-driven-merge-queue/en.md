# Event-Driven Merge-Queue Trigger

Status: draft

## Context
The merge-queue automation ([`merge-queue-automation`](../merge-queue-automation/en.md))
reconciles the board and applies the `automerge` label on a scheduled (cron)
poll, because on a personal GitHub account the "card moved to `Done`" gesture has
no native event. Everything *downstream* of the label is already event-driven:
the target repository's automerge workflow triggers on `pull_request` / `label`
events. So exactly one hop is poll-based — "board `Status` = `Done` → `automerge`
label" — and this spec catalogues the options to make that single hop
event-driven, weighs their trade-offs, and records the recommended direction so a
future implementation picks a sanctioned path instead of re-deriving it.

This spec is a decision record and option catalogue. It does not replace the
poll-based reconciliation; it defines what an event-driven trigger would look
like and when it is worth the cost.

## Goals
- Make the "ready to ship → `automerge` label" transition event-driven
  (near-real-time) rather than poll-based, where the cost is justified
- Keep the option set explicit and decided, so an implementation picks a
  sanctioned path rather than re-litigating the platform constraints
- Preserve the single board as the maintainer's surface either way

## Non-Goals
- The poll-based reconciliation, board population, and archived-repo prune —
  owned by [`merge-queue-automation`](../merge-queue-automation/en.md)
- What happens after the label is applied — the gh-plumbing automerge workflow
  and the `release-automation` / `branching-model` specs
- The board's views and fields — [`portfolio-board`](../portfolio-board/en.md)
  and [`portfolio-views`](../portfolio-views/en.md)

## Requirements

### Platform constraints (the facts this decision rests on)
- **MUST** acknowledge that on **user-account** projects there are **no**
  `projects_v2_item` webhooks (the event is organisation-only) and **no**
  `on: projects_v2_item` GitHub Actions trigger; a board-item move therefore
  cannot drive a workflow natively on a personal account
- **MUST** acknowledge that everything downstream of the `automerge` label is
  already event-driven, so the scope of this spec is exactly the one hop
  "board `Done` → label"

### Option A — Label as the trigger gesture (recommended; no org, no infra)
- The human "ready" gesture is **applying a label** on the pull request (the
  `automerge` label directly, or an intermediate `ready` / `ship` label a
  workflow translates into `automerge`) instead of dragging a card to `Done`. The
  `pull_request: [labeled]` event fires **natively** → event-driven, zero polling
- The board's `Done` column becomes a **view filtered by that label**, not the
  trigger; the label is the source of truth and the board reflects it
- **Trade-off:** applying a label is a slightly less rich gesture than
  drag-and-drop; the two **MAY** be coupled (board for overview, label for the
  trigger). Net cost is low

### Option B — Organisation migration + GitHub App / webhook receiver
- Move the projects under a GitHub **Organisation**, where `projects_v2_item`
  webhooks fire. A GitHub App or webhook receiver reacts to "item edited,
  `Status` → `Done`" and applies the label in near-real-time
- Since June 2024 the `projects_v2_item.edited` payload carries the field's
  previous and current value, so "`Status` changed to `Done`" is detected cleanly
- This is the **only** way to keep the board-drag gesture **and** be event-driven
- **Trade-off:** organisation migration of the projects plus a running receiver
  (GitHub App + a serverless endpoint). Highest cost

### Option C — External webhook receiver + `repository_dispatch` (needs the org from B)
- The organisation webhook reaches a small serverless function that re-emits a
  `repository_dispatch` into the target repository, where a workflow applies the
  label or starts the release. Latency in seconds; depends on the organisation
  model of Option B

### Not viable on a personal account (recorded to prevent re-litigation)
- User-account project webhooks; an Actions trigger for project items; GraphQL
  subscriptions for project changes; a GitHub App reaching user-level V2 projects

### Decision
- **Option A** is the recommended path while the portfolio stays on a personal
  account: event-driven, no polling, no extra service — the only cost is changing
  the trigger gesture from a board drag to a label
- **Option B / C** is warranted **only** if the board-drag gesture must remain the
  trigger, which requires the organisation model
- Until an event-driven option is implemented, the cron poll in
  [`merge-queue-automation`](../merge-queue-automation/en.md) remains the
  fallback, with its accepted latency floor of ~5 minutes

## Acceptance Criteria
- [ ] The spec records the platform constraint (no user-account project webhooks, no Actions project-item trigger) and that everything downstream of the label is already event-driven
- [ ] Each option (A label-trigger, B org + webhook/App, C external receiver + `repository_dispatch`) is documented with mechanism, latency, dependencies, and trade-offs
- [ ] A recommendation is recorded: Option A for the personal-account model; Option B/C only to keep the drag gesture
- [ ] If Option A is adopted, applying the trigger label fires a native `pull_request: [labeled]` workflow, and the board's `Done` column is a label-filtered view with the label as the source of truth
- [ ] The poll-based reconciliation in [`merge-queue-automation`](../merge-queue-automation/en.md) is recorded as the fallback until an event-driven option ships

## Open Questions
- Which trigger label for Option A — reuse `automerge` directly, or an
  intermediate `ready` / `ship` label that a workflow translates into `automerge`
  (keeping `automerge` purely machine-set)?
- Is the cron poll's latency actually a problem for a solo portfolio, or is
  event-driven a premature optimisation here?
- If the portfolio ever moves to an organisation for other reasons, does Option B
  become the default trigger model?

## References
- `projects_v2_item` webhooks are organisation-only:
  <https://github.com/orgs/community/discussions/17405>;
  GitHub Docs, *Types of webhooks*
  (<https://docs.github.com/en/webhooks/types-of-webhooks>)
- No `on: projects_v2_item` Actions trigger:
  <https://github.com/orgs/community/discussions/40848>;
  GitHub Docs, *Events that trigger workflows*
  (<https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows>)
- The `pull_request: [labeled]` and `label` events are native Actions triggers:
  GitHub Docs, *Events that trigger workflows* (same URL)
