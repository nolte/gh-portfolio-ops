#!/usr/bin/env bash
#
# Sync open nolte/* pull requests onto a Projects V2 board and apply the
# `automerge` label to every PR whose card has been dragged into "Done".
#
# Required environment:
#   GH_TOKEN         classic PAT with `repo` + `project` scopes (or fine-grained
#                    PAT: Pull requests RW + Projects RW on all nolte repos)
#   PROJECT_NUMBER   the Projects V2 number (e.g. 7 for .../users/nolte/projects/7)
# Optional:
#   OWNER            default: nolte
#   DONE_OPTION      Status option that triggers the label, default: Done
#   LABEL            label to apply, default: automerge
#
set -euo pipefail

OWNER="${OWNER:-nolte}"
PROJECT_NUMBER="${PROJECT_NUMBER:?set PROJECT_NUMBER (e.g. 7)}"
DONE_OPTION="${DONE_OPTION:-Done}"
LABEL="${LABEL:-automerge}"

echo "::group::Add open ${OWNER}/* PRs to project #${PROJECT_NUMBER}"
# --archived=false: never sync PRs from archived repositories. Archived repos are
# read-only, their open PRs can't be merged, and they would only clutter the board.
mapfile -t PR_URLS < <(gh search prs --owner "$OWNER" --state open --archived=false --limit 200 --json url --jq '.[].url')
echo "Found ${#PR_URLS[@]} open PRs"
for url in "${PR_URLS[@]}"; do
  # item-add is idempotent: re-adding an existing PR returns the existing item.
  if gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$url" >/dev/null 2>&1; then
    echo "  + $url"
  else
    echo "  ! could not add: $url"
  fi
done
echo "::endgroup::"

echo "::group::Scan board items (collect across all pages)"
read -r -d '' QUERY <<'GRAPHQL' || true
query($login:String!, $number:Int!, $cursor:String){
  user(login:$login){
    projectV2(number:$number){
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
ARCHIVED_IDS=()   # project-item ids whose PR lives in an archived repo -> prune
DONE_URLS=()      # open, non-archived PRs sitting in the Done column   -> label
cursor=""
while : ; do
  if [ -z "$cursor" ]; then
    resp=$(gh api graphql -f query="$QUERY" -F login="$OWNER" -F number="$PROJECT_NUMBER")
  else
    resp=$(gh api graphql -f query="$QUERY" -F login="$OWNER" -F number="$PROJECT_NUMBER" -F cursor="$cursor")
  fi

  while read -r id; do [ -n "$id" ] && ARCHIVED_IDS+=("$id"); done < <(echo "$resp" | jq -r '
    .data.user.projectV2.items.nodes[]
    | select(.content?.repository?.isArchived == true)
    | .id')

  while read -r prurl; do [ -n "$prurl" ] && DONE_URLS+=("$prurl"); done < <(echo "$resp" | jq -r --arg doneopt "$DONE_OPTION" '
    .data.user.projectV2.items.nodes[]
    | select(.status?.name == $doneopt)
    | select(.content?.state == "OPEN")
    | select(.content?.repository?.isArchived != true)
    | .content.url')

  hasNext=$(echo "$resp" | jq -r '.data.user.projectV2.items.pageInfo.hasNextPage')
  cursor=$(echo  "$resp" | jq -r '.data.user.projectV2.items.pageInfo.endCursor')
  [ "$hasNext" = "true" ] || break
done
echo "::endgroup::"

echo "::group::Prune items from archived repositories"
pruned=0
for id in "${ARCHIVED_IDS[@]}"; do
  if gh project item-delete "$PROJECT_NUMBER" --owner "$OWNER" --id "$id" >/dev/null 2>&1; then
    pruned=$((pruned+1))
  else
    echo "  ! could not delete item ${id} — skipped"
  fi
done
echo "Pruned ${pruned} item(s) from archived repositories."
echo "::endgroup::"

echo "::group::Label PRs in '${DONE_OPTION}' with '${LABEL}'"
labeled=0
for prurl in "${DONE_URLS[@]}"; do
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
    labeled=$((labeled+1))
  else
    echo "     ! could not add '$LABEL' (label missing in ${nwo} or PR not editable) — skipped"
  fi
done
echo "Applied '${LABEL}' to ${labeled} PR(s)."
echo "::endgroup::"
