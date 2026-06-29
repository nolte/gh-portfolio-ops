# Unreleased Changes — Detecting Merged-but-Unreleased Pull Requests

Status: draft

## Context
Between two published releases a repository accumulates pull requests that are
already merged into the line of development but have not yet shipped to users.
This portfolio drafts releases continuously — `release-drafter` maintains a
*draft* GitHub Release on every push to `develop` (see
[`portfolio-views`](../portfolio-views/en.md) §Release notes / changelog) — and
publishes them only on demand via the `release-publish` workflow, after which
`release-cd-refresh-master` fast-forwards `main` to the release tag. The gap
between "merged" and "released" is therefore a real, often multi-day window, and
nothing today makes it visible: the board's
[`Release management`](../portfolio-views/en.md) view shows what is *ready to
ship*, not what has *already shipped versus what is still pending a release*.

This spec governs how a pull request's **unreleased** status is determined and
how the set of merged-but-unreleased pull requests is surfaced — per repository
and rolled up across `nolte/*`. It binds to the audience and detail-level model
in [`view-design-principles`](../view-design-principles/en.md) (Maintainer —
release management) and extends the [`portfolio-views`](../portfolio-views/en.md)
catalogue with an `Unreleased` view. It defines the **detection contract and its
view**, not the versioning or publication mechanics those releases run on.

## Goals
- Determine, robustly and per pull request, whether a merged pull request is part
  of a published release or still pending one ("unreleased")
- Make the merged-but-unreleased set visible per repository and as a portfolio
  roll-up, so the release decision is informed by what is waiting to ship
- Anchor the determination on data that survives the repository's merge strategy
  (squash, merge commit, or rebase) and its develop→main release flow
- Reuse the surfaces this portfolio already runs — the `release-drafter` draft
  release, the GitHub compare API, release tags — rather than introduce a new
  source of truth

## Non-Goals
- Release versioning, tag creation, and publication mechanics — owned by the
  `release-automation` and `branching-model` specs and the existing
  `release-drafter` / `release-publish` / `release-cd-*` workflows
- The reusable audience, detail-level, and form model — owned by
  [`view-design-principles`](../view-design-principles/en.md)
- The board's fields and the `Done` → `automerge` handoff — owned by
  [`portfolio-board`](../portfolio-board/en.md) and
  [`merge-queue-automation`](../merge-queue-automation/en.md); a pull request is
  *unreleased* strictly after it is merged, which is downstream of that handoff
- Provisioning of any token or repository variable — owned by Terraform in
  `terraform-github-bootstrap` (`terraform/portfolio-ops/`)
- Multiple independent version lines within one repository (component/monorepo
  tags) — this portfolio runs one version line per repository (see Open Questions)

## Requirements

### Definitions
- The **released baseline** of a repository **MUST** be the most recent
  *published* GitHub Release — `draft: false` — and the git tag it points at.
  Draft releases (including `release-drafter`'s own continuously-updated draft)
  **MUST NOT** count as the baseline. The treatment of pre-releases
  (`prerelease: true`) **MUST** be an explicit, documented policy choice, not an
  accident of the API's default ordering
- The **development tip** **MUST** be the head of the repository's line of
  development (`develop` in this portfolio's branching model), i.e. where merges
  land
- A merged pull request is **unreleased** if and only if its merge commit is
  reachable from the development tip **and not** reachable from the released
  baseline tag. Equivalently, it appears in the commit range
  `<released-baseline-tag>..<development-tip>` and not before it

### Detection method
- Detection **MUST** anchor on the pull request's `merge_commit_sha` (and the
  presence of `merged_at`), **not** on the pull request's head-branch commits.
  GitHub records a pull request as merged and stamps `merge_commit_sha` under all
  three merge strategies, but squash and rebase **rewrite** the original branch
  SHAs, so matching by head-branch commits silently misses squash- and
  rebase-merged pull requests. `merge_commit_sha` is the one identifier that is
  reachable from the base branch regardless of strategy
- Containment **MUST** be computed against the released baseline, by either:
  - the GitHub compare API,
    `GET /repos/{owner}/{repo}/compare/{baseline_tag}...{development_tip}`, whose
    returned commits are exactly the unreleased commits; or
  - git-native containment of the merge commit in release tags
    (`git tag --contains <merge_commit_sha>` / `git describe --contains`),
    treating *no published-release tag contains it* as unreleased
- Each unreleased commit **MUST** be mapped to its originating pull request via
  the "List pull requests associated with a commit" endpoint
  (`GET /repos/{owner}/{repo}/commits/{sha}/pulls`) or the GraphQL
  `Commit.associatedPullRequests` connection. The deduplicated set of associated,
  merged pull requests is the merged-but-unreleased set
- The detection **SHOULD** prefer the existing `release-drafter` **draft release**
  as its economical primary source: that draft already enumerates every pull
  request merged since the last published release, categorised by
  Conventional-Commits label, and is refreshed on each push to `develop`. When
  the draft is used, it **MUST** be treated as *unreleased by definition* (a draft
  is not published), and the compare/`associatedPullRequests` method above **MUST**
  remain available as the authoritative cross-check when no draft exists or the
  draft is stale
- The detection **MAY** use the read-only
  `POST /repos/{owner}/{repo}/releases/generate-notes` endpoint
  (`previous_tag_name` = baseline) to obtain the same pull-request listing without
  maintaining a draft

### Edge cases
- **Merge strategy** — the determination **MUST** hold identically for
  squash-merge, merge-commit, and rebase-merge, by anchoring on `merge_commit_sha`
  per the detection rule above
- **Commits without a pull request** — commits pushed directly to the development
  line (no associated pull request) **MUST NOT** break detection: they appear in
  the unreleased range but map to an empty pull-request set, and the view
  **SHOULD** account for such commit-level unreleased changes rather than dropping
  them silently
- **Rewritten history** — release tags **MUST** be treated as immutable reference
  points; the baseline **MUST** be pinned to the published tag's commit, so a
  force-push to the development line cannot misreport containment
- **Reverted merges** — a pull request merged and then reverted before the next
  release is still reported by the range method (both its merge and the revert are
  unreleased); the view **MAY** note net-no-op pairs but **MUST NOT** be required
  to reconcile them
- **No prior release** — a repository with no published release yet **MUST** treat
  every merged pull request on the development line as unreleased (the baseline is
  the empty/root reference)

### View and presentation
- The catalogue **MUST** provide an **Unreleased** view. Audience: Maintainer —
  release management (per [`view-design-principles`](../view-design-principles/en.md)).
  Leading question: *what has merged since the last release and is waiting to
  ship?* Primary detail level: item-level (one row per pull request),
  summarising toward an aggregated per-repository count
- The view **MUST** show, per pull request, at least its title, number, author,
  merge date, and Conventional-Commits category, and **SHOULD** surface the
  predicted next version derived by the `release-drafter` version resolver
- The view **MUST** offer a **portfolio roll-up** across `nolte/*` — at minimum
  the count of unreleased pull requests per repository and the age of the oldest
  unreleased merge — so a repository sitting on a long-pending release is visible
  at a glance, honouring the overview-first heuristic in
  [`view-design-principles`](../view-design-principles/en.md)
- The view **MUST** exclude already-released pull requests and in-progress
  (unmerged) work; it is the counterpart to the
  [`Release management`](../portfolio-views/en.md) view (ready-to-ship,
  pre-merge), separated by the merge boundary

### Implementation binding
- The concern **MUST** follow the repository's one-concern model: its logic lives
  in a script under `scripts/` (testable, shellcheck-clean), invoked by a thin
  workflow under `.github/workflows/`, per `CLAUDE.md`
- Any token or repository variable the detection needs **MUST** be provisioned by
  Terraform (`terraform-github-bootstrap`), never set by hand; read-only release,
  tag, and compare data needs only standard repository read scope

## Acceptance Criteria
- [ ] A pull request's unreleased status is defined as: merged, reachable from the development tip, and not reachable from the latest *published* release tag
- [ ] The released baseline excludes draft releases (including the `release-drafter` draft) and applies an explicit pre-release policy
- [ ] Detection anchors on `merge_commit_sha`, so squash-, merge-commit-, and rebase-merged pull requests are all detected
- [ ] The unreleased set is computed via the compare API (or git tag-containment) and mapped to pull requests via the associated-pull-requests endpoint/connection
- [ ] The `release-drafter` draft release is usable as the economical primary source, with the compare/associated-pull-requests method as the authoritative cross-check
- [ ] Commits with no associated pull request and repositories with no prior release are handled without breaking detection
- [ ] An **Unreleased** view exists for the release-management audience at item level, showing per-pull-request detail and the predicted next version
- [ ] The view offers a portfolio roll-up (per-repository unreleased count and oldest-unreleased-merge age) and excludes released and unmerged work
- [ ] The concern is realised as a `scripts/` script plus a thin workflow, with any credentials Terraform-provisioned

## Open Questions
- Should a published **pre-release** (`prerelease: true`, e.g. a release
  candidate) count as "released" for this view, or should the baseline always be
  the latest *full* release so changes shipped only in an RC still read as
  unreleased?
- Is the **`release-drafter` draft** trusted as the single source for the view, or
  must every run reconcile it against the compare/associated-pull-requests result
  to catch drift (draft body staleness, manual edits, category misassignment)?
- For the portfolio roll-up, what threshold turns an "oldest unreleased merge age"
  into an actionable signal (a colour, an alert) rather than mere information —
  and does that belong here or in the `release-automation` spec?
- Should commit-level unreleased changes with no pull request be promoted into the
  view as first-class rows, or only counted, given direct pushes to `develop` are
  discouraged by the branching model?

## References
- GitHub REST, *Commits* — compare two commits
  (`GET /repos/{owner}/{repo}/compare/{basehead}`) and *List pull requests
  associated with a commit* (`GET /repos/{owner}/{repo}/commits/{commit_sha}/pulls`).
  <https://docs.github.com/en/rest/commits/commits>
- GitHub Docs, *About pull request merges* — merge-commit vs. squash vs. rebase
  and how each rewrites or preserves commit SHAs.
  <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges>
- GitHub Docs, *Automatically generated release notes* — the `generate-notes`
  API and `previous_tag_name` compare behaviour.
  <https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes>
- `release-drafter/release-drafter` — continuously maintained draft release of
  pull requests merged since the last published release.
  <https://github.com/release-drafter/release-drafter>
- `int128/list-associated-pull-requests-action` — lists the pull requests
  associated with the commits between two refs; the canonical building block for
  "what merged since the last release".
  <https://github.com/int128/list-associated-pull-requests-action>
- `mikepenz/release-changelog-builder-action` — builds a categorised changelog
  between two tags via associated pull requests.
  <https://github.com/mikepenz/release-changelog-builder-action>
- `Songmu/tagpr` — the "release pull request" pattern: an open pull request
  accumulates the unreleased changes and flips to a tag on merge.
  <https://github.com/Songmu/tagpr>
- Git-native containment: `git tag --contains <sha>` / `git describe --contains`
  (<https://adamj.eu/tech/2024/04/22/git-show-first-containing-tag/>);
  `mhagger/git-when-merged` (<https://github.com/mhagger/git-when-merged>);
  *Finding changes since the last release*
  (<https://www.semicomplete.com/blog/geekery/finding-changes-since-last-release/>)
