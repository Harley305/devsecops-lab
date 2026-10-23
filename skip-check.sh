#!/usr/bin/env bash
# Skip check: every Checkov skip in the Terraform code must be registered in
# EXCEPTIONS.md, give a reason, and point to the register. Stops a skip from
# being slipped into a PR without a documented risk decision, and flags register
# entries whose skip has been removed.
# Exit 0 = in sync, 1 = unregistered, malformed or stale entry found.
set -uo pipefail

cd "$(dirname "$0")" || exit 1
register=EXCEPTIONS.md
total=0 bad=0
shopt -s nocasematch # Checkov accepts checkov:skip= and bridgecrew:skip= in any case
re='(checkov|bridgecrew):skip= *([A-Za-z0-9_]*) *:? *(.*)$'

while IFS= read -r hit; do
  loc=$(cut -d: -f1,2 <<<"$hit")
  total=$((total + 1))
  [[ $hit =~ $re ]] || { echo "  FAIL  $loc: unreadable skip"; bad=$((bad + 1)); continue; }
  id=${BASH_REMATCH[2]} reason=${BASH_REMATCH[3]}

  if [ -z "$id" ]; then
    echo "  FAIL  $loc: no check ID"; bad=$((bad + 1))
  elif [ -z "$reason" ]; then
    echo "  FAIL  $loc: $id has no reason"; bad=$((bad + 1))
  elif ! grep -qE "^\| ${id} \||${id} \(skipped" "$register"; then
    echo "  FAIL  $loc: $id is not registered in $register"; bad=$((bad + 1))
  elif [[ $reason != *EXCEPTIONS.md* ]]; then
    echo "  FAIL  $loc: $id reason does not point to $register"; bad=$((bad + 1))
  else
    echo "  OK    $loc: $id"
  fi
done < <(grep -rniE '(checkov|bridgecrew):skip=' --include='*.tf' . | sort)

# Reverse direction: every accepted exception must still have a skip in the
# code, so the register can't keep entries for checks that now pass.
code_ids=$(grep -rhoiE '(checkov|bridgecrew):skip= *[A-Za-z0-9_]+' --include='*.tf' . \
  | sed -E 's/.*= *//' | tr '[:lower:]' '[:upper:]' | sort -u)
registered=$( { awk '/^## Accepted exceptions/{f=1;next} /^## /{f=0} f && /^\| CKV/{print $2}' "$register"
  grep -oE 'CKV[0-9]*_[A-Z]+_[0-9]+ \(skipped' "$register" | cut -d' ' -f1; } | sort -u)
stale=0
for id in $registered; do
  if ! grep -qx "$id" <<<"$code_ids"; then
    echo "  STALE $register: $id is registered but no longer skipped in code"; stale=$((stale + 1))
  fi
done

echo "Checked $total skips: $((total - bad)) registered, $bad failing; $stale stale register entries"
[ "$bad" -eq 0 ] && [ "$stale" -eq 0 ]
