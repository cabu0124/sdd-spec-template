#!/usr/bin/env bash
#
# The gates the docs promise, enforced: a status that is one of the five, the
# approval gate (an approved spec has no open question left), the id shape and
# number every consumer's spec.link.yml depends on, no unfilled <...>
# placeholder committed, a supersession both specs agree on, and an acceptance
# criterion that names a requirement the spec actually states.
#
#   scripts/spec-check.sh                       # every spec under specs/
#   scripts/spec-check.sh specs/014-password-reset
#
# See docs/lifecycle.md.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

field() {
  sed -n "s/^- \*\*$2:\*\*[[:space:]]*//p" "$1" \
    | head -n1 \
    | sed -e 's/<!--.*-->//' -e 's/[[:space:]]*$//'
}

# The five statuses in docs/lifecycle.md. Anything else — a typo, a status
# nobody defined, a header that lost the line — reads downstream as "not
# published", so the spec stops being buildable without anyone saying so.
valid_status() {
  case "$1" in
    draft|review|approved|done|superseded) return 0 ;;
    *) return 1 ;;
  esac
}

failed=0
checked=0

check_one() {
  local dir=$1 spec slug status successor reqs refs ref
  dir="${dir%/}"
  spec="$dir/spec.md"
  slug=$(basename "$dir")

  if [ ! -f "$spec" ]; then
    echo "::error::$dir has no spec.md"
    failed=1
    return
  fi
  checked=$((checked + 1))

  if [[ ! "$slug" =~ ^[0-9]{3}-[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "::error file=$spec::directory name '$slug' is not NNN-slug, zero-padded (docs/lifecycle.md)"
    failed=1
  fi

  # A placeholder starts with a letter — <!-- --> comments and <NNN-slug>
  # style values both would, so this only flags the literal <...> left unfilled.
  if grep -qE '<[A-Za-z][^>]*>' "$spec"; then
    echo "::error file=$spec::an unfilled <...> placeholder is still committed"
    failed=1
  fi

  status=$(field "$spec" Status)

  if ! valid_status "$status"; then
    echo "::error file=$spec::status is '${status:-(empty)}' — it must be one of draft, review, approved, done, superseded (docs/lifecycle.md)"
    failed=1
  fi

  if [ "$status" = approved ]; then
    # Open questions are checkboxes; a resolved one is struck through, not
    # deleted, so an unchecked box — not any text in the section — is the gate.
    if awk '/^## Open questions/{f=1;next} /^## /{f=0} f' "$spec" | grep -q '^- \[ \]'; then
      echo "::error file=$spec::status is approved but ## Open questions still has an unchecked item (docs/lifecycle.md)"
      failed=1
    fi
  fi

  if [ "$status" = superseded ]; then
    successor=$(field "$spec" "Superseded by")
    if [ -z "$successor" ]; then
      echo "::error file=$spec::status is superseded but Superseded by: is empty"
      failed=1
    elif [ ! -f "specs/$successor/spec.md" ]; then
      echo "::error file=$spec::Superseded by: names '$successor', which is not a spec in specs/"
      failed=1
    elif [ "$(field "specs/$successor/spec.md" Supersedes)" != "$slug" ]; then
      # Recorded on the retired spec alone, the chain is invisible from the
      # successor — which is the end a consumer arrives at.
      echo "::error file=specs/$successor/spec.md::this spec supersedes $slug, but its Supersedes: does not say so"
      failed=1
    fi
  fi

  # Every acceptance criterion names the requirement it verifies, and that
  # requirement has to exist: `- [ ] **AC1** (R1) — ...`.
  reqs=$(awk '/^## Requirements/{f=1;next} /^## /{f=0} f' "$spec" \
    | sed -n 's/^-[[:space:]]*\*\*\(R[0-9][0-9]*\)\*\*.*/\1/p')
  refs=$(awk '/^## Acceptance criteria/{f=1;next} /^## /{f=0} f' "$spec" \
    | sed -n 's/.*\*\*AC[0-9][0-9]*\*\*[[:space:]]*(\([^)]*\)).*/\1/p' \
    | tr ',' '\n' | tr -d '[:blank:]' | tr -d '\r')
  for ref in $refs; do
    printf '%s\n' "$reqs" | grep -qx "$ref" && continue
    echo "::error file=$spec::an acceptance criterion names $ref, which is not a requirement in ## Requirements"
    failed=1
  done
}

shopt -s nullglob
if [ "$#" -eq 0 ]; then
  set -- specs/*/
fi

for dir in "$@"; do
  [ -d "$dir" ] || continue
  check_one "$dir"
done

# A repeated number is invisible from inside either spec, and the number is
# what a consumer's spec.link.yml records. Scan the whole directory for it
# whatever this run was asked to check.
dupes=$(
  for dir in specs/*/; do
    [ -f "${dir%/}/spec.md" ] || continue
    basename "$dir" | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p'
  done | sort | uniq -d
)
if [ -n "$dupes" ]; then
  while read -r number; do
    [ -n "$number" ] || continue
    echo "::error::number $number belongs to more than one spec — ids are never reused (docs/lifecycle.md)"
    failed=1
  done <<<"$dupes"
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "No specs yet."
else
  echo "$checked spec(s): statuses, ids, placeholders, open questions, supersessions and criteria all clean."
fi
