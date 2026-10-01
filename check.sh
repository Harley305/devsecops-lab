#!/usr/bin/env bash
# Run Terraform format, init and validate checks on every Terraform folder.
# Usage: ./check.sh
set -euo pipefail

cd "$(dirname "$0")"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

for dir in infra bootstrap; do
  echo "==> [$dir] Checking formatting"
  if ! terraform -chdir="$dir" fmt -check -recursive; then
    red "FAIL: the files above need formatting. Fix with: terraform -chdir=$dir fmt -recursive"
    exit 1
  fi

  echo "==> [$dir] Initializing"
  terraform -chdir="$dir" init -backend=false -input=false > /dev/null

  echo "==> [$dir] Validating"
  if ! terraform -chdir="$dir" validate; then
    red "FAIL: validation errors above in $dir"
    exit 1
  fi
done

green "PASS: all checks passed"
