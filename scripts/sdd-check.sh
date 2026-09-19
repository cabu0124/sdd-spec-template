#!/usr/bin/env bash
#
# Every check this repository runs, in one command — the same one for a
# developer, for an agent and for CI. A check only the pipeline knows how to
# run is a check you meet after review.
#
#   scripts/sdd-check.sh
#   scripts/sdd-check.sh --verbose
#
# A passing check is worth one line. Compact is the default, so what is left on
# screen is what went wrong; --verbose prints every check's output in full, and
# a failing check always keeps its full output one `scripts/sdd-recall.sh` away.
#
# It writes nothing outside .sdd/recall/. See docs/lifecycle.md and AGENTS.md.

set -uo pipefail

here=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

. "$here/sdd-lib.sh" || { echo "sdd-check: scripts/sdd-lib.sh is missing" >&2; exit 1; }

failed=0
checked=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

run() {
  local label=$1
  shift
  checked=$((checked + 1))

  if sdd_verbose; then
    echo "==> $label"
    "$@" || failed=1
    echo
    return
  fi

  local log="$work/check"
  if "$@" > "$log" 2>&1; then
    # The last line a check prints is its own summary; it earns the one line.
    sdd_ok "$label — $(sed -e '/^[[:space:]]*$/d' "$log" | tail -n1)"
    return
  fi

  failed=1
  sdd_fail "$label"
  sdd_dedupe_lines < "$log" | sdd_truncate_lines >&2
  printf '[full output: scripts/sdd-recall.sh %s]\n' "$(bash "$here/sdd-recall.sh" --save < "$log")" >&2
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
  --verbose|-v) SDD_VERBOSE=1 ;;
  "") ;;
  *) echo "sdd-check: unknown option: $1" >&2; exit 2 ;;
esac

run "Specs only — no plans, no task lists" specs_only
run "Statuses, ids, criteria and verification" bash scripts/spec-check.sh
run "Spec validator behavioral fixtures" bash scripts/test-spec-check.sh
run "Model routing reaches every generated adapter" bash scripts/test-sdd-onboard.sh
run "Compacted output stays faithful to what the command said" bash scripts/test-sdd-compact.sh
run "The rewrite hook fails open and never approves" bash scripts/test-sdd-hook.sh
run "Recall store caps, isolates and returns what it stored" bash scripts/test-sdd-recall.sh
run "Upgrades respect what this repository edited" bash scripts/test-sdd-upgrade.sh
run "specs/INDEX.md matches the spec headers" bash scripts/spec-index.sh --check

if ! sdd_verbose; then
  printf '\n%d check(s) run, %d failed.\n' "$checked" "$failed"
fi

exit "$failed"
