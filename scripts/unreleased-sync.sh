#!/usr/bin/env bash
#
# Surface merged-but-unreleased pull requests across nolte/* on the merge-queue
# board (#PROJECT_NUMBER) in the "Unreleased" Status column, downstream of Done.
#
# A merged PR is "unreleased" iff its merge_commit_sha is reachable from the
# repository's development tip (develop, or the default branch) and NOT from the
# latest *published* release tag (the released baseline). Anchoring on
# merge_commit_sha means squash-, rebase-, and merge-commit merges all detect.
# Per spec/unreleased-changes/.
#
# Required environment:
#   GH_TOKEN         token with repo read + project read/write
#   PROJECT_NUMBER   the Projects V2 board number
# Optional:
#   OWNER             default: nolte
#   UNRELEASED_OPTION Status option name, default: Unreleased
#
# Note: repositories with no published release are skipped (the "merged since the
# last release" window is undefined) rather than flooding the board with their
# whole merged history; they are counted in the run summary.
#
# The $-prefixed names inside the single-quoted `gh api graphql -f query='…'`
# strings below are GraphQL variables, not shell variables — they must not expand.
# shellcheck disable=SC2016
set -euo pipefail

OWNER="${OWNER:-nolte}"
PROJECT_NUMBER="${PROJECT_NUMBER:?set PROJECT_NUMBER}"
UNRELEASED_OPTION="${UNRELEASED_OPTION:-Unreleased}"

# Resolve project id, Status field id, and the Unreleased option id up front.
read -r PROJECT_ID FIELD_ID OPTION_ID < <(gh api graphql -f query='
query($l:String!,$n:Int!){
  user(login:$l){ projectV2(number:$n){
    id
    field(name:"Status"){ ... on ProjectV2SingleSelectField { id options { id name } } }
  }}
}' -F l="$OWNER" -F n="$PROJECT_NUMBER" \
  --jq ".data.user.projectV2 | [.id, .field.id, ((.field.options[] | select(.name==\"$UNRELEASED_OPTION\") | .id) // \"\")] | @tsv")

if [ -z "${OPTION_ID:-}" ]; then
  echo "No '$UNRELEASED_OPTION' Status option on project #$PROJECT_NUMBER — add it in the board UI first." >&2
  exit 1
fi

echo "::group::Compute merged-but-unreleased PRs across ${OWNER}/*"
mapfile -t REPOS < <(gh repo list "$OWNER" --no-archived --source --limit 300 --json nameWithOwner --jq '.[].nameWithOwner')
echo "Scanning ${#REPOS[@]} non-archived repositories"

UNRELEASED_URLS=()
no_release=0
for repo in "${REPOS[@]}"; do
  # Released baseline = latest published (non-draft, non-prerelease) release tag.
  baseline=$(gh api "repos/$repo/releases" --jq 'map(select(.draft==false and .prerelease==false)) | (.[0].tag_name // "")' 2>/dev/null || true)
  if [ -z "$baseline" ]; then
    no_release=$((no_release + 1))
    continue
  fi

  # Development tip = develop when present, else the default branch.
  if gh api "repos/$repo/branches/develop" >/dev/null 2>&1; then
    tip="develop"
  else
    tip=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null || true)
  fi
  [ -n "$tip" ] || continue

  # Unreleased commit SHAs = the compare range baseline...tip.
  shas=$(gh api "repos/$repo/compare/$baseline...$tip" --jq '.commits[].sha' 2>/dev/null || true)
  [ -n "$shas" ] || continue

  # Merged PRs anchored on merge_commit_sha; keep those whose merge commit is
  # in the unreleased range (survives squash / rebase / merge-commit strategies).
  while IFS=$'\t' read -r prurl mc; do
    [ -z "$prurl" ] && continue
    if grep -qxF "$mc" <<<"$shas"; then
      UNRELEASED_URLS+=("$prurl")
    fi
  done < <(gh pr list --repo "$repo" --state merged --limit 100 \
    --json url,mergeCommit --jq '.[] | select(.mergeCommit.oid != null) | [.url, .mergeCommit.oid] | @tsv')
done
echo "Found ${#UNRELEASED_URLS[@]} merged-but-unreleased PR(s); skipped ${no_release} repo(s) with no published release."
echo "::endgroup::"

echo "::group::Upsert onto board #${PROJECT_NUMBER} (Status='${UNRELEASED_OPTION}')"
for prurl in "${UNRELEASED_URLS[@]+"${UNRELEASED_URLS[@]}"}"; do
  item_id=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$prurl" --format json --jq '.id' 2>/dev/null || true)
  if [ -z "$item_id" ]; then
    echo "  ! could not add $prurl"
    continue
  fi
  if gh api graphql -f query='mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){projectV2Item{id}}}' \
    -F p="$PROJECT_ID" -F i="$item_id" -F f="$FIELD_ID" -F o="$OPTION_ID" >/dev/null 2>&1; then
    echo "  -> $prurl"
  else
    echo "  ! could not set status: $prurl"
  fi
done
echo "::endgroup::"

# Prune items currently in Unreleased whose PR is no longer unreleased (shipped in
# a release since the last run). Reads the first 100 board items; the Unreleased
# set is expected to stay small.
echo "::group::Prune now-released items from '${UNRELEASED_OPTION}'"
pruned=0
while IFS=$'\t' read -r item_id prurl; do
  [ -z "$item_id" ] && continue
  keep=0
  for u in "${UNRELEASED_URLS[@]+"${UNRELEASED_URLS[@]}"}"; do
    [ "$u" = "$prurl" ] && {
      keep=1
      break
    }
  done
  if [ "$keep" -eq 0 ]; then
    gh project item-delete "$PROJECT_NUMBER" --owner "$OWNER" --id "$item_id" >/dev/null 2>&1 && pruned=$((pruned + 1))
  fi
done < <(gh api graphql -f query='query($l:String!,$n:Int!){user(login:$l){projectV2(number:$n){items(first:100){nodes{id status:fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}} content{... on PullRequest{url}}}}}}}' \
  -F l="$OWNER" -F n="$PROJECT_NUMBER" \
  --jq ".data.user.projectV2.items.nodes[] | select(.status.name==\"$UNRELEASED_OPTION\") | [.id, .content.url] | @tsv")
echo "Pruned ${pruned} now-released item(s)."
echo "::endgroup::"
