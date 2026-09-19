#!/usr/bin/env bash
#
# Run a command and print a condensed version of what it said.
#
#   scripts/sdd-compact.sh <command> [args...]
#   scripts/sdd-compact.sh --verbose <command> [args...]
#
# Four strategies, per command: drop the noise, group what repeats, collapse
# identical lines, and truncate the middle of anything long. The exit code is
# the command's own, untouched.
#
# Whenever a command fails or its output was trimmed, the full output is kept
# by scripts/sdd-recall.sh and the id to read it back with is printed. Nothing
# has to be re-run to see what was cut.
#
# The command is executed as given — arguments are never rewritten, and the
# shell never re-parses them.

set -uo pipefail

here=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

. "$here/sdd-lib.sh" || { echo "sdd-compact: scripts/sdd-lib.sh is missing" >&2; exit 1; }

die() { printf 'sdd-compact: %s\n' "$1" >&2; exit "${2:-1}"; }

while [ "$#" -gt 0 ]; do
  case $1 in
    --verbose | -v) SDD_VERBOSE=1; shift ;;
    --help | -h) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

[ "$#" -gt 0 ] || die 'pass the command to run' 2

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

out="$work/out"
err="$work/err"

"$@" > "$out" 2> "$err"
code=$?

if sdd_verbose; then
  cat "$out"
  cat "$err" >&2
  exit "$code"
fi

# git dispatches on its subcommand, so find it: the first bare word that is not
# the value of a flag that takes one.
subcommand_of_git() {
  local skip=0 arg
  for arg in "$@"; do
    if [ "$skip" -eq 1 ]; then skip=0; continue; fi
    case $arg in
      -C | -c | --git-dir | --work-tree) skip=1 ;;
      -*) ;;
      *) printf '%s' "$arg"; return 0 ;;
    esac
  done
}

filter_key() {
  local name
  name=$(basename -- "$1")
  case $name in
    git)
      shift
      printf 'git:%s' "$(subcommand_of_git "$@")"
      ;;
    sdd-*.sh | spec-*.sh) printf 'sdd-script' ;;
    *) printf 'generic' ;;
  esac
}

# A long list of paths says less than the count and the states they are in.
filter_git_status() {
  sdd_drop_matching '^[[:space:]]*\(use "|^[[:space:]]*$|^no changes added to commit' \
    | sed -e 's/^\t//' -e 's/:[[:space:]][[:space:]]*/: /' \
    | sdd_group_by_prefix
}

filter_git_log() {
  awk '
    /^commit [0-9a-f]/ { sha = substr($2, 1, 7); pending = 1; next }
    /^(Author|AuthorDate|Commit|CommitDate|Date|Merge):/ { next }
    pending && NF { sub(/^[[:space:]]+/, ""); print sha " " $0; pending = 0; next }
    !pending && /^commit/ { next }
    !sha { print }
  '
}

# The body of a diff is the single largest thing an agent gets asked to read,
# and the least of it is load-bearing. Name the files and the shape; the body
# stays one recall away. Output that is not a patch passes through.
filter_git_diff() {
  awk '
    { line[NR] = $0 }
    /^diff --git / { files++; name = $4; sub(/^b\//, "", name); paths[files] = name; next }
    /^\+\+\+ |^--- / { next }
    /^\+/ { added++; next }
    /^-/ { removed++; next }
    END {
      if (!files) {
        for (i = 1; i <= NR; i++) print line[i]
        exit
      }
      printf "%d file(s) changed, +%d -%d\n", files, added, removed
      for (i = 1; i <= files; i++) print "  " paths[i]
    }
  '
}

# Every `ok:` line says the same thing: something passed. The count says it once.
filter_sdd_script() {
  awk '
    /^ok: / { passed++; next }
    { print }
    END { if (passed) printf "ok: %d check(s) passed\n", passed }
  '
}

apply_filter() {
  case $(filter_key "$@") in
    git:status) filter_git_status ;;
    git:log | git:show) filter_git_log ;;
    git:diff) filter_git_diff ;;
    git:add | git:commit | git:push | git:pull | git:fetch)
      if [ "$code" -eq 0 ]; then
        cat > /dev/null
        printf 'ok: %s\n' "$*"
      else
        cat
      fi
      ;;
    sdd-script) filter_sdd_script ;;
    *) cat ;;
  esac
}

apply_filter "$@" < "$out" | sdd_dedupe_lines | sdd_truncate_lines > "$work/out.compact"
sdd_dedupe_lines < "$err" | sdd_truncate_lines > "$work/err.compact"

lines() { wc -l < "$1" | tr -d ' '; }

trimmed=0
if [ "$(lines "$work/out.compact")" -lt "$(lines "$out")" ] \
  || [ "$(lines "$work/err.compact")" -lt "$(lines "$err")" ]; then
  trimmed=1
fi

cat "$work/out.compact"
cat "$work/err.compact" >&2

if [ "$code" -ne 0 ] || [ "$trimmed" -eq 1 ]; then
  id=$(
    {
      printf '$ %s\n' "$*"
      printf -- '--- stdout ---\n'
      cat "$out"
      printf -- '--- stderr ---\n'
      cat "$err"
      printf -- '--- exit: %d ---\n' "$code"
    } | bash "$here/sdd-recall.sh" --save
  )
  # The hint has to be runnable from wherever the agent is, so it stays absolute
  # unless this repository is that directory.
  recall="$here/sdd-recall.sh"
  case $recall in "$PWD"/*) recall="${recall#"$PWD"/}" ;; esac
  [ -n "$id" ] && printf '[full output: %s %s]\n' "$recall" "$id"
fi

exit "$code"
