#!/usr/bin/env bash
# Decide whether a pull request touches any of the given path patterns.
#
# Why: the backend workflows used `on.pull_request.paths`. A required status
# check from a workflow that never starts stays "Expected" forever, so those
# checks could not be made required. The workflows now always start; this
# script decides whether their heavy jobs run. A skipped job satisfies a
# required check through the workflow's gate job.
#
# Usage: pr-touches.sh PATTERN...
#   Patterns use bash glob matching, where `*` also matches `/`
#   (so `apps/backend/*` covers the whole subtree).
# Output: `matched=true|false` appended to $GITHUB_OUTPUT (stdout if unset).
#
# Inputs (environment):
#   GITHUB_EVENT_NAME   anything other than pull_request => matched=true
#   PR_NUMBER, GITHUB_REPOSITORY, GH_TOKEN   used to list the PR's files
#   CHANGED_FILES_FILE  optional: newline-separated file list (tests only)
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "pr-touches.sh: at least one pattern is required" >&2
  exit 2
fi

out="${GITHUB_OUTPUT:-/dev/stdout}"

if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]]; then
  echo "matched=true" >>"$out"
  exit 0
fi

if [[ -n "${CHANGED_FILES_FILE:-}" ]]; then
  files="$(cat "$CHANGED_FILES_FILE")"
else
  : "${PR_NUMBER:?PR_NUMBER is required for pull_request events}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
  files="$(gh api --paginate "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" --jq '.[].filename')"
fi

# A PR with an unreadable or empty file list runs the heavy jobs: failing
# open to "run everything" is the safe direction for a required check.
if [[ -z "$files" ]]; then
  echo "matched=true" >>"$out"
  exit 0
fi

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  for pattern in "$@"; do
    # shellcheck disable=SC2053 # glob match is intended
    if [[ "$file" == $pattern ]]; then
      echo "pr-touches.sh: '$file' matches '$pattern'" >&2
      echo "matched=true" >>"$out"
      exit 0
    fi
  done
done <<<"$files"

echo "matched=false" >>"$out"
