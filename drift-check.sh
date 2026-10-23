#!/usr/bin/env bash
# Drift check: compares live AWS resources against the Terraform code.
# Checks every stack in TF_DIRS (default: infra bootstrap).
# Exit 0 = no drift, 2 = drift found, 1 = error.
set -uo pipefail

cd "$(dirname "$0")" || exit 1
overall=0

for d in ${TF_DIRS:-infra bootstrap}; do
  echo "==> Checking for drift in $d (profile: ${AWS_PROFILE:-default})"
  terraform -chdir="$d" plan -detailed-exitcode -lock=false -input=false -no-color > "/tmp/drift-plan-$d.txt" 2>&1
  code=$?

  case $code in
    0) echo "PASS: no drift in $d. Live infrastructure matches the code." ;;
    2) echo "DRIFT: live infrastructure in $d differs from the code:"
       grep -E "^\s+# |^\s+[-+~] |^Plan:" "/tmp/drift-plan-$d.txt"
       [ "$overall" -eq 0 ] && overall=2 ;;
    *) echo "ERROR: plan failed in $d:"
       cat "/tmp/drift-plan-$d.txt"
       overall=1 ;;
  esac
done
exit $overall
