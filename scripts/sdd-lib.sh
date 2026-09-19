#!/usr/bin/env bash
#
# Shared helpers for every SDD script: logging, and the four primitives that
# keep output small enough for an agent to read cheaply — filter, group,
# truncate, deduplicate.
#
# Source it, do not run it:
#
#   . "$(dirname "$0")/sdd-lib.sh"
#
# Compact is the default, deliberately: an agent reads this output on every run
# and pays for every line of it. SDD_VERBOSE=1, or a script's own --verbose,
# restores the full output for a human or for CI.

SDD_VERBOSE=${SDD_VERBOSE:-0}
SDD_HEAD_LINES=${SDD_HEAD_LINES:-20}
SDD_TAIL_LINES=${SDD_TAIL_LINES:-10}

sdd_verbose() { [ "$SDD_VERBOSE" = "1" ]; }

sdd_ok() { printf 'ok: %s\n' "$1"; }
sdd_note() { printf 'note: %s\n' "$1"; }
sdd_warn() { printf 'warning: %s\n' "$1" >&2; }
sdd_fail() { printf 'error: %s\n' "$1" >&2; }

# A CI annotation, which GitHub renders on the file it names. Kept verbatim in
# compact mode: these are the lines worth reading.
sdd_annotate() {
  local level=$1 file=$2 message=$3
  printf '::%s file=%s::%s\n' "$level" "$file" "$message" >&2
}

# Collapse identical lines anywhere in the stream, in first-seen order.
sdd_dedupe_lines() {
  awk '
    { if (!($0 in count)) order[++n] = $0; count[$0]++ }
    END {
      for (i = 1; i <= n; i++) {
        line = order[i]
        if (count[line] > 1) printf "%s  (x%d)\n", line, count[line]
        else print line
      }
    }
  '
}

# Keep the head and the tail, and say how much was dropped in between.
sdd_truncate_lines() {
  awk -v head="${1:-$SDD_HEAD_LINES}" -v tail="${2:-$SDD_TAIL_LINES}" '
    { line[NR] = $0 }
    END {
      if (NR <= head + tail) {
        for (i = 1; i <= NR; i++) print line[i]
        exit
      }
      for (i = 1; i <= head; i++) print line[i]
      printf "... %d line(s) elided ...\n", NR - head - tail
      for (i = NR - tail + 1; i <= NR; i++) print line[i]
    }
  '
}

# "prefix: value" lines become one line per prefix, values joined. Anything
# without a prefix passes through untouched and in place.
sdd_group_by_prefix() {
  awk '
    {
      pos = index($0, ": ")
      if (pos == 0) { order[++n] = $0; kind[n] = "raw"; next }
      key = substr($0, 1, pos - 1)
      value = substr($0, pos + 2)
      if (key in seen) { joined[key] = joined[key] ", " value; next }
      seen[key] = 1
      order[++n] = key
      kind[n] = "group"
      joined[key] = value
    }
    END {
      for (i = 1; i <= n; i++) {
        if (kind[i] == "group") printf "%s: %s\n", order[i], joined[order[i]]
        else print order[i]
      }
    }
  '
}

# Drop the lines matching an extended regex — the noise a human skims past.
sdd_drop_matching() {
  grep -Ev "$1" || true
}
