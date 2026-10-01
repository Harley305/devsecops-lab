#!/usr/bin/env bash
# Run Terraform format, init and validate checks on infra/.
# Usage: ./check.sh
set -euo pipefail

cd "$(dirname "$0")/infra"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

echo "==> Checking formatting"
if ! terraform fmt -check -recursive; then
  red "FAIL: the files above need formatting. Fix with: terraform -chdir=infra fmt -recursive"
  exit 1
fi

echo "==> Initializing"
terraform init -backend=false -input=false > /dev/null

echo "==> Validating"
if ! terraform validate; then
  red "FAIL: validation errors above"
  exit 1
fi

green "PASS: all checks passed"
