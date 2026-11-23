#!/usr/bin/env bash
# Tests for pr-touches.sh. Run: bash .github/scripts/pr-touches.test.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
subject="$here/pr-touches.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

run_case() {
  local name="$1" event="$2" files="$3" expected="$4"
  shift 4
  printf '%s' "$files" >"$work/files"
  : >"$work/out"
  GITHUB_EVENT_NAME="$event" CHANGED_FILES_FILE="$work/files" GITHUB_OUTPUT="$work/out" \
    bash "$subject" "$@" 2>/dev/null
  local actual
  actual="$(cat "$work/out")"
  if [[ "$actual" == "matched=$expected" ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected matched=$expected, got '$actual'"
    failures=$((failures + 1))
  fi
}

run_case "docs-only PR skips backend" pull_request \
  $'docs/architecture/LAUNCH_STATUS.md\nREADME.md' false 'apps/backend/*' '.github/workflows/backend-r0.yml'
run_case "nested backend file matches subtree" pull_request \
  $'docs/x.md\napps/backend/functions/src/dev_booking_entry.ts' true 'apps/backend/*'
run_case "exact workflow path matches" pull_request \
  '.github/workflows/backend-r0.yml' true 'apps/backend/*' '.github/workflows/backend-r0.yml'
run_case "glob inside file name" pull_request \
  'apps/backend/scripts/check-n4c-plan.test.mjs' true 'apps/backend/scripts/check-n4c-plan*.mjs'
run_case "similar prefix does not match" pull_request \
  'apps/backend-old/readme.md' false 'apps/backend/*'
run_case "empty file list runs everything" pull_request \
  '' true 'apps/backend/*'
run_case "push event always runs" push \
  'docs/x.md' true 'apps/backend/*'
run_case "manual dispatch always runs" workflow_dispatch \
  'docs/x.md' true 'apps/backend/*'

if GITHUB_EVENT_NAME=pull_request bash "$subject" >/dev/null 2>&1; then
  echo "FAIL no patterns: expected non-zero exit"
  failures=$((failures + 1))
else
  echo "ok   no patterns is a usage error"
fi

if [[ $failures -ne 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all pr-touches tests passed"
