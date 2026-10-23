#!/usr/bin/env bash
# Skip check: every Checkov skip in the Terraform code must be registered in
# EXCEPTIONS.md, give a reason, and point to the register. Stops a skip from
# being slipped into a PR without a documented risk decision.
# Exit 0 = all skips registered, 1 = unregistered or malformed skip found.
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

echo "Checked $total skips: $((total - bad)) registered, $bad failing"
[ "$bad" -eq 0 ]
