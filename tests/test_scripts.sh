#!/usr/bin/env bash
# Minimal validation: every automation script must parse as valid bash.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

while IFS= read -r -d '' script; do
  if bash -n "$script"; then
    echo "ok: $script"
  else
    echo "FAIL: $script" >&2
    status=1
  fi
done < <(find "$repo_root/scripts" "$repo_root/bootstrap.sh" -name '*.sh' -print0 2>/dev/null)

exit "$status"
