#!/usr/bin/env bash
# Policy check: runs every IAM policy and S3 bucket policy in the Terraform
# code through IAM Access Analyzer policy validation (ValidatePolicy, free).
# Compensating control for CIS 1.19: this account's SCP blocks creating an
# Access Analyzer, but allows policy checks.
#
# Usage: ./policy-check.sh [DIR ...]       (default: infra)
#        PLAN_FILE=tfplan ./policy-check.sh infra   reuse a saved plan in DIR
#
# Exit 0 = no blocking findings, 2 = ERROR or SECURITY_WARNING found, 1 = error.
# WARNING and SUGGESTION findings are reported but don't fail the check.
set -uo pipefail

cd "$(dirname "$0")" || exit 1
export AWS_REGION="${AWS_REGION:-us-east-2}" AWS_PAGER=""
[ $# -eq 0 ] && set -- infra

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
checked=0 skipped=0 blocking=0 advisory=0

# Pull each policy document out of the plan's planned values, with the
# policy type Access Analyzer needs for it.
extract='
  [.planned_values.root_module | .. | objects | select(has("resources")) | .resources[]]
  | .[] | select(.mode == "managed")
  | if .type == "aws_iam_role" then
      {addr: .address, type: "RESOURCE_POLICY", rtype: "AWS::IAM::AssumeRolePolicyDocument", doc: .values.assume_role_policy}
    elif (.type | IN("aws_iam_role_policy", "aws_iam_policy", "aws_iam_user_policy", "aws_iam_group_policy")) then
      {addr: .address, type: "IDENTITY_POLICY", rtype: "", doc: .values.policy}
    elif .type == "aws_s3_bucket_policy" then
      {addr: .address, type: "RESOURCE_POLICY", rtype: "AWS::S3::Bucket", doc: .values.policy}
    else empty end
  | @base64'

for dir in "$@"; do
  echo "==> [$dir] Reading planned policies"
  if [ -n "${PLAN_FILE:-}" ]; then
    plan="$PLAN_FILE"
  else
    plan="$work/$(basename "$dir").tfplan"
    if ! terraform -chdir="$dir" plan -lock=false -input=false -no-color -out="$plan" > "$work/plan.log" 2>&1; then
      echo "ERROR: plan failed in $dir:"; grep -E '^(Error|│)' "$work/plan.log" | head -n 20; exit 1
    fi
  fi
  terraform -chdir="$dir" show -json "$plan" > "$work/plan.json" || { echo "ERROR: could not read plan in $dir"; exit 1; }

  while IFS= read -r row; do
    item=$(printf '%s' "$row" | base64 --decode)
    addr=$(jq -r .addr <<<"$item"); ptype=$(jq -r .type <<<"$item")
    rtype=$(jq -r .rtype <<<"$item"); doc=$(jq -r '.doc // empty' <<<"$item")

    if [ -z "$doc" ]; then
      echo "  SKIP  $addr (policy not known until apply)"; skipped=$((skipped + 1)); continue
    fi

    args=(accessanalyzer validate-policy --policy-type "$ptype" --policy-document "$doc" --output json)
    [ -n "$rtype" ] && args+=(--validate-policy-resource-type "$rtype")
    if ! out=$(aws "${args[@]}" 2>&1); then
      echo "ERROR: validate-policy failed for $addr:"; echo "$out" | head -n 5; exit 1
    fi
    checked=$((checked + 1))

    findings=$(jq -r '.findings[] | "\(.findingType) \(.issueCode): \(.findingDetails)"' <<<"$out")
    if [ -z "$findings" ]; then
      echo "  OK    $addr"
    else
      while IFS= read -r f; do
        case $f in
          ERROR*|SECURITY_WARNING*) echo "  FAIL  $addr  $f"; blocking=$((blocking + 1)) ;;
          *)                        echo "  NOTE  $addr  $f"; advisory=$((advisory + 1)) ;;
        esac
      done <<<"$findings"
    fi
  done < <(jq -r "$extract" "$work/plan.json")
done

echo
echo "Checked $checked policies, skipped $skipped. Blocking findings: $blocking. Advisory: $advisory."
if [ "$blocking" -gt 0 ]; then
  echo "FAIL: fix the ERROR and SECURITY_WARNING findings above."; exit 2
fi
echo "PASS: no blocking findings."
exit 0
