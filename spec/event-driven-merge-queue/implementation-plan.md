# Event-Driven Board Process — Implementation Plan

Status: draft · Companion to [`event-driven-merge-queue`](./en.md) (the decision
record) and [`board-status-transitions`](../board-status-transitions/en.md) (the
state machine this plan makes event-driven).

This is an engineering plan for a *later* full implementation, not a normative
spec. It analyses how the poll-based board lifecycle can become event-driven on a
personal GitHub account, picks a target architecture, and sequences the work into
phases with deliverables, acceptance, and risks. English-only by intent (an
internal engineering artifact, like a README).

---

## 1. Purpose and scope

Today the board (#5) is reconciled by two cron pollers:

- `merge-queue-sync` (`*/10`) — adds open PRs (T1), applies `automerge` to
  `Done`+open PRs (T3), prunes archived-repo items (T8).
- `unreleased-sync` (hourly) — moves merged PRs to `Unreleased` (T5), removes
  released PRs (T6), discovers merged-unreleased PRs (T7).

(Transition IDs T1–T9 are defined in
[`board-status-transitions`](../board-status-transitions/en.md).)

**Goal of the migration:** drive the board from GitHub *events* instead of polling,
so transitions land in seconds rather than within `*/10` or the hour, the
per-run full-portfolio scans disappear, and the system reacts to exactly the
changes that happened.

**Scope:** transitions T1, T3, T5, T6, T7, T8. T2 is human (stays manual). T4 is
already event-driven (the target repo's automerge workflow). T9 (Auto-archive) is
orthogonal.

**Out of scope:** changing the *meaning* of any transition (that is
`board-status-transitions`), and release versioning (that is `release-automation`).

## 2. Baseline metrics (what we are improving)

| Dimension | Today (poll) | Target (event-driven) |
|---|---|---|
| `Done` → merge label latency (T3) | ≤ ~10 min + scheduler jitter | seconds (on the trigger event) |
| merged → `Unreleased` latency (T5) | ≤ ~1 h | seconds (on `pull_request closed`) |
| released → off-board latency (T6) | ≤ ~1 h | seconds (on `release published`) |
| API cost | every run scans all repos (releases, compare, PR list, board pages) | one targeted update per real event |
| Wasted runs | most runs find nothing changed | none — runs only on change |

## 3. Hard constraints (the facts the design must obey)

These are established in [`event-driven-merge-queue`](./en.md) and the
deep-research record:

1. **No board-move events on a personal account.** `projects_v2_item` webhooks
   are organisation-only, and GitHub Actions has no `on: projects_v2_item`
   trigger. A *card move* (T2 → `Done`) therefore cannot be an event source.
2. **The underlying PR/release events *are* available at the repository level.**
   `pull_request` (`opened`/`reopened`/`closed`), `release` (`published`) are
   both webhook events and GitHub Actions triggers on each `nolte/*` repo. This
   is the lever: react to the PR/release lifecycle, not to the board.
3. **There is no `on: repository` Actions trigger.** The `repository` webhook
   (`archived`) exists, but Actions cannot trigger on it. So T8 (archived-repo
   prune) cannot be made Actions-event-driven; it needs the webhook path
   (Option 2) or stays on a low-frequency reconcile.
4. **A GitHub App cannot write a *user-level* Projects V2 board.** The board
   *write* side must keep using the classic PAT (`project` scope, today's
   `MERGE_QUEUE_TOKEN`) in *either* architecture. Events may be received by an
   App or by Actions, but the GraphQL `updateProjectV2*` calls run with the PAT.
5. **`GITHUB_TOKEN` is scoped to its own repo.** A producer repo cannot use its
   `GITHUB_TOKEN` to `repository_dispatch` into `gh-portfolio-ops`; that needs a
   token with access to `gh-portfolio-ops` (the portfolio App token, already
   being provisioned, or a dedicated PAT).

## 4. Event source per transition

| Transition | Today (poll) | Native event source | Notes |
|---|---|---|---|
| T1 open PR → board | `merge-queue-sync` scan | `pull_request: [opened, reopened]` | one upsert per opened PR |
| T2 manual triage | human | — (no event) | stays manual, unchanged |
| T3 `Done` → `automerge` label | poll `Status==Done` | **none** (board move) | resolve via label-trigger (Option A) or a reconcile |
| T4 merge | automerge workflow | `pull_request`/`check_suite` (existing) | already event-driven |
| T5 merged → `Unreleased` | hourly scan | `pull_request: [closed]` (`merged==true`) | recompute that one PR's unreleased status |
| T6 released → off-board | hourly scan | `release: [published]` | recompute that repo's unreleased set, prune released |
| T7 discover merged-unreleased | hourly scan | **subsumed by T5** | every merge is caught at merge time; discovery becomes a backfill only |
| T8 archived → off-board | poll `isArchived` | `repository: [archived]` (webhook only) | no Actions trigger → reconcile or App webhook |
| T9 Auto-archive | built-in | built-in | orthogonal |

**Key insight:** once every *merge* and every *release* fires an event (T5, T6),
the polling *discovery* (T7) is no longer needed for steady state — it collapses
into a one-time backfill plus a safety-net reconcile. The hard residue is T3 (the
board move has no event) and T8 (`repository` is not an Actions trigger).

## 5. Target architecture — two options

Both keep the board *write* on the classic PAT (constraint 4) and keep the board
itself on the personal account (no org migration).

### Option 1 — GitHub Actions fan-in via `repository_dispatch` (no hosted infra)

```
nolte/<repo>  --(pull_request/release event)-->  caller workflow
   caller calls gh-plumbing reusable-board-event.yaml
      reusable workflow --(repository_dispatch, App token)--> nolte/gh-portfolio-ops
         gh-portfolio-ops board-event.yml (on: repository_dispatch)
            scripts/board-event.sh --(GraphQL, MERGE_QUEUE_TOKEN)--> board #5
```

- **Producers:** every `nolte/*` repo carries a thin caller
  `.github/workflows/board-event.yml` (distributed the same way `automerge.yaml`
  and `release-drafter.yml` already are) that, on `pull_request`/`release`, calls
  a new `nolte/gh-plumbing/.github/workflows/reusable-board-event.yaml`. That
  reusable workflow `POST`s a `repository_dispatch` to `gh-portfolio-ops` with a
  typed payload (repo, PR url, action, merged flag, release tag) using the
  portfolio App token (constraint 5).
- **Consumer:** `gh-portfolio-ops` gains `.github/workflows/board-event.yml`
  (`on: repository_dispatch: types: [board-event]`) that runs
  `scripts/board-event.sh`, which updates board #5 with `MERGE_QUEUE_TOKEN`.
- **Pros:** GitHub-native, no hosted service, reuses the existing reusable-workflow
  distribution and the App token; the board PAT stays in one repo.
- **Cons:** a workflow must be wired into every `nolte/*` repo; latency is
  seconds-to-a-minute (Actions queueing); `repository` (archived) has no trigger,
  so T8 stays on a reconcile.

### Option 2 — GitHub App + serverless webhook receiver (lowest latency)

```
nolte/<repo>  --(webhook: pull_request/release/repository)-->  GitHub App (nolte-portfolio-app)
   --> serverless receiver (Worker/Lambda)  --(GraphQL, MERGE_QUEUE_TOKEN)-->  board #5
```

- The portfolio App subscribes to `pull_request`, `release`, **and `repository`**
  webhooks across all installed `nolte/*` repos; a small hosted receiver updates
  the board.
- **Pros:** lowest latency (seconds), no per-repo workflow, central, and it *can*
  cover T8 (the `repository archived` webhook is available to the App).
- **Cons:** needs hosted infra (an endpoint + a secret store for the PAT), App
  webhook configuration, and a deployment/runtime to operate and monitor.

### Recommendation

Start with **Option 1** (Actions fan-in): it needs no hosted infrastructure,
rides the plumbing the portfolio already uses, and keeps the board PAT central.
Keep a **low-frequency reconcile** (the existing scripts, demoted to e.g. daily)
as the backstop and as the only owner of T8. Re-evaluate **Option 2** only if the
Actions-queue latency or the per-repo wiring proves unacceptable, or if the
portfolio moves to an organisation (which would *also* unlock native
`projects_v2_item` webhooks and remove the T3 gap entirely — the "nuclear option"
recorded in `event-driven-merge-queue` as Option B).

## 6. Detailed design (Option 1)

### 6.1 Consumer: `gh-portfolio-ops`

- New `scripts/board-event.sh` — a single idempotent board updater that takes the
  event type and payload (via env or `$GITHUB_EVENT_PATH`'s `client_payload`) and
  performs exactly the transition for that event, reusing the helpers already in
  `merge-queue-sync.sh` / `unreleased-sync.sh` (resolve project/field/option ids,
  `set_status`, the `merge_commit_sha`-in-compare-range check):
  - `pr_opened`   → upsert item (T1).
  - `pr_merged`   → if unreleased → upsert + `Status=Unreleased` (T5); else remove (T6 for that PR).
  - `released`    → recompute the repo's unreleased set; for each board item of that repo, keep-or-remove (T6).
  - `pr_labeled`  → (only if Option A adopted) apply `automerge` (T3).
- New `.github/workflows/board-event.yml` — `on: repository_dispatch:
  types: [board-event]`, passes `${{ github.event.client_payload.* }}` into the
  script with `GH_TOKEN: ${{ secrets.MERGE_QUEUE_TOKEN }}`.
- The script **MUST** be idempotent (re-delivered events are harmless) and
  shellcheck-clean, per the one-concern model in `CLAUDE.md`.

### 6.2 Producer: `gh-plumbing` + per-repo caller

- New `nolte/gh-plumbing/.github/workflows/reusable-board-event.yaml`: inputs =
  event facts; secret = the dispatch token; body = a single `gh api
  repos/nolte/gh-portfolio-ops/dispatches -f event_type=board-event -F
  client_payload=…`.
- Per-repo `.github/workflows/board-event.yml` caller, distributed across
  `nolte/*` the same way `automerge.yaml` is, triggering on
  `pull_request: [opened, reopened, closed]` and `release: [published]`, passing
  `secrets.PORTFOLIO_APP_*` so the reusable workflow can mint the dispatch token.

### 6.3 Reconcile backstop

- Keep `merge-queue-sync` and `unreleased-sync`, but **demote their cron** to
  low frequency (e.g. daily) as a safety net for missed events and as the sole
  owner of **T8** (archived prune — no Actions event exists). Keep
  `workflow_dispatch` for on-demand full reconciliation.

## 7. Phased rollout

| Phase | Deliverable | Acceptance | Risk focus |
|---|---|---|---|
| **0 · Decide** | Option 1 vs 2; T3 label-trigger (Option A) yes/no; dispatch-auth model | decisions recorded in `event-driven-merge-queue` | scope creep |
| **1 · Consumer** | `scripts/board-event.sh` + `board-event.yml` (`repository_dispatch`) in gh-portfolio-ops; covers T1/T5/T6 | a manual `gh api …/dispatches` with a crafted payload performs the right board update; idempotent on re-send | board-write auth, idempotency |
| **2 · Producer pilot** | `reusable-board-event.yaml` in gh-plumbing + caller wired into 2–3 pilot repos | opening/merging a PR and publishing a release in a pilot repo updates the board within a minute, no poll | dispatch token scope, payload shape |
| **3 · Portfolio rollout** | caller distributed to all `nolte/*` (via gh-plumbing settings/template) | every active repo emits board events | per-repo wiring drift |
| **4 · Demote polls** | `merge-queue-sync`/`unreleased-sync` cron → daily reconcile; T8 stays here | board stays correct with events as primary, reconcile as backstop; drift report clean | missed events, races |
| **5 · T3 + hardening** | label-trigger for ready-to-ship (Option A) *or* keep board-drag + reconcile; logging, missed-event/drift detection | T3 latency acceptable; an injected missed event is caught by reconcile and reported | the residual board-move gap |

## 8. Risks and mitigations

- **Board write needs the PAT (constraint 4).** Both options keep
  `MERGE_QUEUE_TOKEN` as the board-write credential; the App is only an *event
  source*, never the board writer. No change to the token model.
- **No event for `repository archived` in Actions (constraint 3).** T8 stays on
  the reconcile cron (Option 1) or moves to the App webhook (Option 2). Documented,
  not silently dropped.
- **The board move (T3) has no event.** Either adopt the label-trigger (Option A,
  fully event-driven) or accept that the "ready to ship" → label step relies on
  the reconcile cron. This is the one transition the personal-account model cannot
  make natively event-driven without an org.
- **Missed / out-of-order events.** Webhook and `repository_dispatch` delivery is
  at-least-once but not guaranteed; the daily reconcile is the authoritative
  backstop, and all board updates are idempotent and last-writer-wins.
- **Dispatch-token blast radius.** Spreading a board-write PAT into every producer
  repo would be a security regression; the fan-in design keeps the board PAT in
  `gh-portfolio-ops` only and uses the portfolio App token (already provisioned)
  for the cross-repo dispatch.
- **Latency floor (Option 1).** Actions queueing adds seconds-to-a-minute; if that
  is unacceptable, Option 2's webhook receiver is the lower-latency fallback.

## 9. Open decisions (carry into Phase 0)

- **Option 1 (Actions fan-in) vs Option 2 (App + serverless receiver).** Default:
  Option 1, unless hosted infra is already on the table.
- **T3:** keep the board-drag gesture (reconcile-backed) or switch the
  ready-to-ship trigger to a label (Option A, fully event-driven)?
- **Dispatch auth:** portfolio App token vs a dedicated minimal-scope PAT for the
  `repository_dispatch` into `gh-portfolio-ops`.
- **Org migration (Option B):** out of scope here, but the only path that makes
  *board moves themselves* event-driven; revisit if the portfolio ever becomes an
  organisation for other reasons.

## 10. References

- [`event-driven-merge-queue`](./en.md) — the options decision record (A/B/C)
- [`board-status-transitions`](../board-status-transitions/en.md) — the transition
  catalogue this plan rewires
- [`merge-queue-automation`](../merge-queue-automation/en.md),
  [`unreleased-changes`](../unreleased-changes/en.md) — the poll-based mechanics
  this plan replaces, and the helpers `board-event.sh` reuses
- GitHub Docs — *Events that trigger workflows* (`pull_request`, `release`,
  `repository_dispatch`; absence of `repository`/`projects_v2_item` triggers);
  *Creating a repository dispatch event*
