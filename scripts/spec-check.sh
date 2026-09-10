#!/usr/bin/env bash
#
# Four gates the docs already promised and nothing enforced until now: the
# approval gate (an approved spec has no open question left), the id shape
# every consumer's spec.link.yml depends on, no unfilled <...> placeholder
# committed, and a superseded spec naming its successor.
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

failed=0
checked=0

check_one() {
  local dir=$1 spec slug status
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

  if [ "$status" = approved ]; then
    # Open questions are checkboxes; a resolved one is struck through, not
    # deleted, so an unchecked box — not any text in the section — is the gate.
    if awk '/^## Open questions/{f=1;next} /^## /{f=0} f' "$spec" | grep -q '^- \[ \]'; then
      echo "::error file=$spec::status is approved but ## Open questions still has an unchecked item (docs/lifecycle.md)"
      failed=1
    fi
  fi

  if [ "$status" = superseded ]; then
    if [ -z "$(field "$spec" "Superseded by")" ]; then
      echo "::error file=$spec::status is superseded but Superseded by: is empty"
      failed=1
    fi
  fi
}

shopt -s nullglob
if [ "$#" -eq 0 ]; then
  set -- specs/*/
fi

for dir in "$@"; do
  [ -d "$dir" ] || continue
  check_one "$dir"
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "No specs yet."
else
  echo "$checked spec(s): status, id shape, placeholders and open questions all clean."
fi
