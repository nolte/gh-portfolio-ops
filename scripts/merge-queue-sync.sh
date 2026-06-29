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
mapfile -t PR_URLS < <(gh search prs --owner "$OWNER" --state open --limit 200 --json url --jq '.[].url')
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

echo "::group::Label PRs in '${DONE_OPTION}' with '${LABEL}'"
read -r -d '' QUERY <<'GRAPHQL' || true
query($login:String!, $number:Int!, $cursor:String){
  user(login:$login){
    projectV2(number:$number){
      items(first:100, after:$cursor){
        pageInfo{ hasNextPage endCursor }
        nodes{
          status: fieldValueByName(name:"Status"){
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
          content{
            ... on PullRequest { url state isDraft repository{ nameWithOwner } }
          }
        }
      }
    }
  }
}
GRAPHQL

cursor=""
labeled=0
while : ; do
  if [ -z "$cursor" ]; then
    resp=$(gh api graphql -f query="$QUERY" -F login="$OWNER" -F number="$PROJECT_NUMBER")
  else
    resp=$(gh api graphql -f query="$QUERY" -F login="$OWNER" -F number="$PROJECT_NUMBER" -F cursor="$cursor")
  fi

  while read -r prurl; do
    [ -z "$prurl" ] && continue
    echo "  -> $prurl"
    if gh pr edit "$prurl" --add-label "$LABEL" >/dev/null 2>&1; then
      labeled=$((labeled+1))
    else
      echo "     ! label '$LABEL' missing in that repo (or PR not editable) — skipped"
    fi
  done < <(echo "$resp" | jq -r --arg done "$DONE_OPTION" '
    .data.user.projectV2.items.nodes[]
    | select(.status?.name == $done)
    | select(.content?.state == "OPEN")
    | .content.url')

  hasNext=$(echo "$resp" | jq -r '.data.user.projectV2.items.pageInfo.hasNextPage')
  cursor=$(echo  "$resp" | jq -r '.data.user.projectV2.items.pageInfo.endCursor')
  [ "$hasNext" = "true" ] || break
done
echo "Applied '${LABEL}' to ${labeled} PR(s)."
echo "::endgroup::"
