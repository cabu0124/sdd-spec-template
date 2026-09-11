#!/usr/bin/env bash
#
# Every check this repository runs, in one command — the same one for a
# developer, for an agent and for CI. A check only the pipeline knows how to
# run is a check you meet after review.
#
#   scripts/sdd-check.sh
#
# It writes nothing. See docs/lifecycle.md and AGENTS.md.

set -uo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

failed=0

run() {
  local label=$1
  shift
  echo "==> $label"
  "$@" || failed=1
  echo
}

# Rule 1, and the reason this repository is separate: a plan or a task list
# here would make the Spec Repository decide how every consumer builds.
specs_only() {
  local stray file
  stray=$(git ls-files -- 'plan.md' '*/plan.md' 'tasks.md' '*/tasks.md')
  if [ -n "$stray" ]; then
    while read -r file; do
      echo "::error file=$file::a plan or a task list belongs to the repository that builds the spec, never here (AGENTS.md, Rule 1)"
    done <<<"$stray"
    return 1
  fi
  echo "No plans or task lists. Specs only."
}

case "${1:-}" in
  --help|-h)
    awk 'NR > 1 && /^#/ { sub(/^#[[:space:]]?/, ""); print; next } NR > 1 { exit }' "$0"
    exit 0
    ;;
  "") ;;
  *) echo "sdd-check: unknown option: $1" >&2; exit 2 ;;
esac

run "Specs only — no plans, no task lists" specs_only
run "Statuses, ids, criteria and verification" bash scripts/spec-check.sh
run "specs/INDEX.md matches the spec headers" bash scripts/spec-index.sh --check

exit "$failed"
