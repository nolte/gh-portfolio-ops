#!/usr/bin/env bash
#
# Sync open nolte/* pull requests onto a Projects V2 board and apply the
# `automerge` label to every PR whose card has been dragged into "Done".
#
# The board may be owned by a user or an organisation; it is addressed by its
# node id (resolved from PROJECT_OWNER + PROJECT_NUMBER), so the GraphQL reads are
# owner-agnostic. Source repositories and the board can have different owners
# (e.g. repos under nolte/*, board under the noltarium org).
#
# Required environment:
#   GH_TOKEN         classic PAT with `repo` + `project` scopes
#   PROJECT_NUMBER   the Projects V2 number (the trailing path segment of its URL)
# Optional:
#   REPO_OWNER       owner of the source repositories, default: nolte (or $OWNER)
#   PROJECT_OWNER    owner of the board (user or org),  default: nolte (or $OWNER)
#   OWNER            back-compat default for both owners above, default: nolte
#   DONE_OPTION      Status option that triggers the label, default: Done
#   LABEL            label to apply, default: automerge
#
set -euo pipefail

OWNER="${OWNER:-nolte}"
REPO_OWNER="${REPO_OWNER:-$OWNER}"
PROJECT_OWNER="${PROJECT_OWNER:-$OWNER}"
PROJECT_NUMBER="${PROJECT_NUMBER:?set PROJECT_NUMBER}"
DONE_OPTION="${DONE_OPTION:-Done}"
LABEL="${LABEL:-automerge}"

# Resolve the board's node id (owner-agnostic via the gh project CLI).
PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json --jq '.id')
[ -n "$PROJECT_ID" ] || {
  echo "Could not resolve project #$PROJECT_NUMBER for owner $PROJECT_OWNER" >&2
  exit 1
}

echo "::group::Add open ${REPO_OWNER}/* PRs to ${PROJECT_OWNER} project #${PROJECT_NUMBER}"
# --archived=false: never sync PRs from archived repositories. Archived repos are
# read-only, their open PRs can't be merged, and they would only clutter the board.
mapfile -t PR_URLS < <(gh search prs --owner "$REPO_OWNER" --state open --archived=false --limit 200 --json url --jq '.[].url')
echo "Found ${#PR_URLS[@]} open PRs"
for url in "${PR_URLS[@]}"; do
  # item-add is idempotent: re-adding an existing PR returns the existing item.
  if gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --url "$url" >/dev/null 2>&1; then
    echo "  + $url"
  else
    echo "  ! could not add: $url"
  fi
done
echo "::endgroup::"

echo "::group::Scan board items (collect across all pages)"
read -r -d '' QUERY <<'GRAPHQL' || true
query($pid:ID!, $cursor:String){
  node(id:$pid){
    ... on ProjectV2 {
      items(first:100, after:$cursor){
        pageInfo{ hasNextPage endCursor }
        nodes{
          id
          status: fieldValueByName(name:"Status"){
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
          content{
            ... on PullRequest { url state isDraft repository{ nameWithOwner isArchived } }
          }
        }
      }
    }
  }
}
GRAPHQL

# Collect across every page BEFORE mutating, so deletions don't shift the cursor.
ARCHIVED_IDS=() # project-item ids whose PR lives in an archived repo -> prune
DONE_URLS=()    # open, non-archived PRs sitting in the Done column   -> label
cursor=""
while :; do
  if [ -z "$cursor" ]; then
    resp=$(gh api graphql -f query="$QUERY" -F pid="$PROJECT_ID")
  else
    resp=$(gh api graphql -f query="$QUERY" -F pid="$PROJECT_ID" -F cursor="$cursor")
  fi

  while read -r id; do [ -n "$id" ] && ARCHIVED_IDS+=("$id"); done < <(echo "$resp" | jq -r '
    .data.node.items.nodes[]
    | select(.content?.repository?.isArchived == true)
    | .id')

  while read -r prurl; do [ -n "$prurl" ] && DONE_URLS+=("$prurl"); done < <(echo "$resp" | jq -r --arg doneopt "$DONE_OPTION" '
    .data.node.items.nodes[]
    | select(.status?.name == $doneopt)
    | select(.content?.state == "OPEN")
    | select(.content?.repository?.isArchived != true)
    | .content.url')

  hasNext=$(echo "$resp" | jq -r '.data.node.items.pageInfo.hasNextPage')
  cursor=$(echo "$resp" | jq -r '.data.node.items.pageInfo.endCursor')
  [ "$hasNext" = "true" ] || break
done
echo "::endgroup::"

echo "::group::Prune items from archived repositories"
pruned=0
for id in "${ARCHIVED_IDS[@]+"${ARCHIVED_IDS[@]}"}"; do
  if gh project item-delete "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --id "$id" >/dev/null 2>&1; then
    pruned=$((pruned + 1))
  else
    echo "  ! could not delete item ${id} — skipped"
  fi
done
echo "Pruned ${pruned} item(s) from archived repositories."
echo "::endgroup::"

echo "::group::Label PRs in '${DONE_OPTION}' with '${LABEL}'"
labeled=0
for prurl in "${DONE_URLS[@]+"${DONE_URLS[@]}"}"; do
  echo "  -> $prurl"
  # Parse https://github.com/<owner>/<repo>/pull/<number>
  nwo=${prurl#https://github.com/}
  nwo=${nwo%/pull/*}
  prnum=${prurl##*/pull/}
  # Use the REST labels endpoint, NOT `gh pr edit --add-label`: the latter
  # queries the deprecated Projects-classic `projectCards` field and fails
  # ("Projects (classic) is being deprecated") on accounts where Projects
  # classic is sunset. Adding an already-present label is a no-op (idempotent).
  if gh api --silent -X POST "repos/${nwo}/issues/${prnum}/labels" \
    -f "labels[]=${LABEL}" 2>/dev/null; then
    labeled=$((labeled + 1))
  else
    echo "     ! could not add '$LABEL' (label missing in ${nwo} or PR not editable) — skipped"
  fi
done
echo "Applied '${LABEL}' to ${labeled} PR(s)."
echo "::endgroup::"
