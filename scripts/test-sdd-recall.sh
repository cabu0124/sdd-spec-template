#!/usr/bin/env bash
# Behavioral fixtures for the recall store.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

recall="$PWD/scripts/sdd-recall.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export SDD_RECALL_DIR="$work/recall"
passed=0

fail() { echo "fixture failed: $1" >&2; exit 1; }
ok() { passed=$((passed + 1)); }

# What goes in comes back out, byte for byte.
printf 'first\nsecond\n\tthird with tab\n' > "$work/payload"
id=$(bash "$recall" --save < "$work/payload")
[ -n "$id" ] || fail 'save returned no id'
bash "$recall" "$id" > "$work/read-back"
cmp -s "$work/payload" "$work/read-back" || fail 'stored output came back changed'
ok

# The store belongs to its owner alone: command output can carry secrets.
mode=$(ls -ld "$SDD_RECALL_DIR" | cut -c1-10)
[ "$mode" = "drwx------" ] || fail "store is $mode, expected drwx------"
ok

bash "$recall" --list | grep -Fqx "$id" || fail '--list did not report the saved id'
ok

# An id names a file in the store and may not wander out of it.
if bash "$recall" '../../etc/passwd' 2>/dev/null; then
  fail 'a traversing id was accepted'
fi
ok

if bash "$recall" 20200101-000000-1 2>/dev/null; then
  fail 'an unknown id was accepted'
fi
ok

# The cap evicts, so the store cannot grow without bound.
SDD_RECALL_MAX_ENTRIES=3
export SDD_RECALL_MAX_ENTRIES
for i in 1 2 3 4 5; do
  printf 'entry %s\n' "$i" | bash "$recall" --save > /dev/null
done
kept=$(bash "$recall" --list | wc -l | tr -d ' ')
[ "$kept" -eq 3 ] || fail "store kept $kept entries, expected 3"
ok
unset SDD_RECALL_MAX_ENTRIES

# A single runaway entry is cut, not stored whole.
SDD_RECALL_MAX_BYTES=64
export SDD_RECALL_MAX_BYTES
big=$(printf 'x%.0s' $(seq 1 500))
id=$(printf '%s\n' "$big" | bash "$recall" --save)
size=$(bash "$recall" "$id" | wc -c | tr -d ' ')
[ "$size" -le 64 ] || fail "entry stored $size bytes, expected at most 64"
ok
unset SDD_RECALL_MAX_BYTES

bash "$recall" --prune
if [ -d "$SDD_RECALL_DIR" ]; then
  fail '--prune left the store behind'
fi
ok

printf '%d sdd-recall fixture(s) passed.\n' "$passed"
