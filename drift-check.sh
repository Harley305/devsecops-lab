#!/usr/bin/env bash
# Drift check: compares live AWS resources against the Terraform code.
# Exit 0 = no drift, 2 = drift found, 1 = error.
set -uo pipefail

cd "$(dirname "$0")/infra" || exit 1

echo "==> Checking for drift in infra (profile: ${AWS_PROFILE:-default})"
terraform plan -detailed-exitcode -lock=false -input=false -no-color > /tmp/drift-plan.txt 2>&1
code=$?

case $code in
  0) echo "PASS: no drift. Live infrastructure matches the code." ;;
  2) echo "DRIFT: live infrastructure differs from the code:"
     grep -E "^\s+# |^\s+[-+~] |^Plan:" /tmp/drift-plan.txt ;;
  *) echo "ERROR: plan failed:"
     cat /tmp/drift-plan.txt ;;
esac
exit $code