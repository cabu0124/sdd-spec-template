#!/usr/bin/env bash
#
# The full output a compact run left behind, so nothing has to be re-run to see
# it. scripts/sdd-compact.sh saves here whenever a command fails or its output
# is trimmed, and prints the id to read it back with.
#
#   scripts/sdd-recall.sh <id>     # print that run's full output
#   scripts/sdd-recall.sh --save   # store stdin, print the new id
#   scripts/sdd-recall.sh --list   # ids kept, newest last
#   scripts/sdd-recall.sh --prune  # drop everything stored
#
# The store is .sdd/recall/, ignored by git and readable only by its owner: a
# command's output can contain anything the command printed, secrets included.
# It is capped at SDD_RECALL_MAX_ENTRIES entries of SDD_RECALL_MAX_BYTES each,
# oldest evicted first.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

store=${SDD_RECALL_DIR:-.sdd/recall}
max_entries=${SDD_RECALL_MAX_ENTRIES:-20}
max_bytes=${SDD_RECALL_MAX_BYTES:-1048576}

die() { printf 'sdd-recall: %s\n' "$1" >&2; exit "${2:-1}"; }

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

# An id names a file in the store, so it may not wander out of it.
valid_id() {
  case $1 in
    *[!A-Za-z0-9._-]* | *..* | '') return 1 ;;
  esac
}

save() {
  umask 077
  mkdir -p "$store"
  chmod 700 "$store" 2>/dev/null || true

  local id suffix=0
  id=$(date '+%Y%m%d-%H%M%S')-$$
  while [ -e "$store/$id.log" ]; do
    suffix=$((suffix + 1))
    id=$(date '+%Y%m%d-%H%M%S')-$$-$suffix
  done

  head -c "$max_bytes" > "$store/$id.log"
  prune_to "$max_entries"
  printf '%s\n' "$id"
}

# Keep the newest $1 entries. Names sort chronologically, so sort order is age.
prune_to() {
  local keep=$1 entry count
  count=$(find "$store" -maxdepth 1 -type f -name '*.log' | wc -l | tr -d ' ')
  [ "$count" -gt "$keep" ] || return 0
  while IFS= read -r entry; do
    [ "$count" -gt "$keep" ] || break
    rm -f "$entry"
    count=$((count - 1))
  done < <(find "$store" -maxdepth 1 -type f -name '*.log' | sort)
}

case "${1:---help}" in
  --help | -h)
    usage
    ;;
  --save)
    save
    ;;
  --list)
    [ -d "$store" ] || exit 0
    find "$store" -maxdepth 1 -type f -name '*.log' | sort | sed -e 's|.*/||' -e 's|\.log$||'
    ;;
  --prune)
    rm -rf "$store"
    ;;
  -*)
    die "unknown option: $1" 2
    ;;
  *)
    valid_id "$1" || die "not an id: $1" 2
    [ -f "$store/$1.log" ] || die "no stored output for $1; it may have been evicted"
    cat "$store/$1.log"
    ;;
esac
