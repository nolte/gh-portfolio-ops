#!/usr/bin/env bash
#
# Surface merged-but-unreleased pull requests across nolte/* on the merge-queue
# board (#PROJECT_NUMBER) in the "Unreleased" Status column, downstream of Done.
#
# A merged PR is "unreleased" iff its merge_commit_sha is reachable from the
# repository's development tip (develop, or the default branch) and NOT from the
# latest *published* release tag (the released baseline). Anchoring on
# merge_commit_sha means squash-, rebase-, and merge-commit merges all detect.
# A repository with no published release treats every merged PR as unreleased.
# Per spec/unreleased-changes/.
#
# Two phases:
#   A. Transition every board item whose PR is merged: unreleased -> Status
#      "Unreleased"; already released -> remove from the board. This moves cards
#      from Done to Unreleased (incl. repos without any release).
#   B. Discover merged-but-unreleased PRs in repos that have a release and are
#      not yet on the board, and add them as Unreleased.
#
# Required environment:
#   GH_TOKEN         token with repo read + project read/write
#   PROJECT_NUMBER   the Projects V2 board number
# Optional:
#   OWNER             default: nolte
#   UNRELEASED_OPTION Status option name, default: Unreleased
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

set_status() { # item_id option_id
  gh api graphql -f query='mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){projectV2Item{id}}}' \
    -F p="$PROJECT_ID" -F i="$1" -F f="$FIELD_ID" -F o="$2" >/dev/null 2>&1
}

# Per-repository unreleased commit set, computed once and cached.
# UNREL_SET[repo] = newline-separated unreleased SHAs, or the literal "__ALL__"
# when the repo has no published release (every merged commit is unreleased).
declare -A UNREL_SET
compute_repo() { # repo
  local repo="$1" baseline tip
  [ -n "${UNREL_SET[$repo]+x}" ] && return 0
  baseline=$(gh api "repos/$repo/releases" --jq 'map(select(.draft==false and .prerelease==false)) | (.[0].tag_name // "")' 2>/dev/null || true)
  if [ -z "$baseline" ]; then
    UNREL_SET[$repo]="__ALL__"
    return 0
  fi
  if gh api "repos/$repo/branches/develop" >/dev/null 2>&1; then
    tip="develop"
  else
    tip=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null || true)
  fi
  UNREL_SET[$repo]=$(gh api "repos/$repo/compare/$baseline...$tip" --jq '.commits[].sha' 2>/dev/null || true)
}

is_unreleased_sha() { # repo sha  -> exit 0 if unreleased
  local repo="$1" sha="$2"
  compute_repo "$repo"
  [ "${UNREL_SET[$repo]}" = "__ALL__" ] && return 0
  grep -qxF "$sha" <<<"${UNREL_SET[$repo]}"
}

# ---- Phase A: transition merged board items ----
echo "::group::Transition merged board items (Done -> Unreleased / drop released)"
moved=0
removed=0
declare -A ON_BOARD
while IFS=$'\t' read -r item_id state nwo sha statusname url; do
  [ -z "$item_id" ] && continue
  ON_BOARD["$url"]=1
  [ "$state" = "MERGED" ] || continue
  if is_unreleased_sha "$nwo" "$sha"; then
    if [ "$statusname" != "$UNRELEASED_OPTION" ]; then
      set_status "$item_id" "$OPTION_ID" && {
        echo "  -> Unreleased: $url"
        moved=$((moved + 1))
      }
    fi
  else
    gh project item-delete "$PROJECT_NUMBER" --owner "$OWNER" --id "$item_id" >/dev/null 2>&1 && {
      echo "  x released, removed: $url"
      removed=$((removed + 1))
    }
  fi
done < <(gh api graphql --paginate -f query='query($l:String!,$n:Int!,$endCursor:String){user(login:$l){projectV2(number:$n){items(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{id status:fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}} content{... on PullRequest{url state mergeCommit{oid} repository{nameWithOwner}}}}}}}}' \
  -F l="$OWNER" -F n="$PROJECT_NUMBER" \
  --jq '.data.user.projectV2.items.nodes[] | select(.content.url != null) | [.id, (.content.state // "-"), (.content.repository.nameWithOwner // "-"), (.content.mergeCommit.oid // "-"), (.status.name // "-"), .content.url] | @tsv')
echo "Phase A: moved ${moved} to '${UNRELEASED_OPTION}', removed ${removed} now-released."
echo "::endgroup::"

# ---- Phase B: discover merged-unreleased PRs not yet on the board ----
echo "::group::Discover merged-but-unreleased PRs across ${OWNER}/*"
mapfile -t REPOS < <(gh repo list "$OWNER" --no-archived --source --limit 300 --json nameWithOwner --jq '.[].nameWithOwner')
echo "Scanning ${#REPOS[@]} non-archived repositories"
added=0
no_release=0
for repo in "${REPOS[@]}"; do
  compute_repo "$repo"
  # Discovery is bounded to repos with a release; merged PRs in release-less repos
  # are surfaced only when they already are board items (handled in Phase A),
  # never by dumping the whole merged history.
  if [ "${UNREL_SET[$repo]}" = "__ALL__" ]; then
    no_release=$((no_release + 1))
    continue
  fi
  [ -n "${UNREL_SET[$repo]}" ] || continue
  while IFS=$'\t' read -r prurl mc; do
    [ -z "$prurl" ] && continue
    [ -n "${ON_BOARD[$prurl]+x}" ] && continue
    if grep -qxF "$mc" <<<"${UNREL_SET[$repo]}"; then
      item_id=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$prurl" --format json --jq '.id' 2>/dev/null || true)
      if [ -z "$item_id" ]; then
        echo "  ! could not add $prurl"
        continue
      fi
      set_status "$item_id" "$OPTION_ID" && {
        echo "  -> Unreleased: $prurl"
        added=$((added + 1))
        ON_BOARD["$prurl"]=1
      }
    fi
  done < <(gh pr list --repo "$repo" --state merged --limit 100 \
    --json url,mergeCommit --jq '.[] | select(.mergeCommit.oid != null) | [.url, .mergeCommit.oid] | @tsv')
done
echo "Phase B: added ${added} newly-discovered; skipped ${no_release} repo(s) with no published release (their board items are handled in Phase A)."
echo "::endgroup::"
