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

# The ## Verification ledger as "AC<tab>verified-at<tab>evidence" rows. Absent
# on a single-repo spec, where the one plan answers for everything.
ledger() {
  awk -F'|' '
    /^## Verification/ { f = 1; next }
    /^## / { f = 0 }
    f && /^[[:space:]]*\|/ {
      ac = $2; at = $4; ev = $5
      gsub(/[*`[:space:]]/, "", ac)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", at)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", ev)
      if (ac ~ /^AC[0-9]+$/) print ac "\t" at "\t" ev
    }
  ' "$1"
}

failed=0
checked=0

check_one() {
  local dir=$1 spec slug status successor reqs refs ref
  local acs ledger_acs ac evidence verified_at consumers ledger_cols
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

  acs=$(awk '/^## Acceptance criteria/{f=1;next} /^## /{f=0} f' "$spec" \
    | sed -n 's/.*\*\*\(AC[0-9][0-9]*\)\*\*.*/\1/p')
  ledger_acs=$(ledger "$spec" | cut -f1)

  # The ledger and the criteria have to describe the same list, or the spec
  # says one thing and the completion record says another.
  if [ -n "$ledger_acs" ]; then
    # A ledger written before `Verified at` existed reads its evidence into the
    # wrong column. Say that, rather than reporting evidence the row plainly has
    # as missing.
    ledger_cols=$(awk -F'|' '/^## Verification/{f=1;next} /^## /{f=0} f && /^[[:space:]]*\|/ {print NF; exit}' "$spec")
    if [ "${ledger_cols:-0}" -lt 6 ]; then
      echo "::error file=$spec::## Verification has three columns and now needs four: AC, Answered by, Verified at, Evidence (docs/lifecycle.md)"
      failed=1
    fi

    for ac in $acs; do
      printf '%s\n' "$ledger_acs" | grep -qx "$ac" && continue
      echo "::error file=$spec::$ac has no row in ## Verification, so no repository answers for it"
      failed=1
    done
    for ac in $ledger_acs; do
      printf '%s\n' "$acs" | grep -qx "$ac" && continue
      echo "::error file=$spec::## Verification names $ac, which is not an acceptance criterion"
      failed=1
    done
  fi

  if [ "$status" = done ]; then
    # More than one consumer and no ledger: every repository passed its own
    # slice and nobody checked the product they add up to.
    consumers=$(field "$spec" Consumers)
    if [ -z "$ledger_acs" ] && [ "$(printf '%s' "$consumers" | grep -c '·')" -gt 0 ]; then
      echo "::error file=$spec::status is done and this spec has more than one consumer, but it has no ## Verification ledger (docs/lifecycle.md)"
      failed=1
    fi

    while IFS="$(printf '\t')" read -r ac verified_at evidence; do
      [ -n "$ac" ] || continue
      [ "${ledger_cols:-6}" -ge 6 ] || break
      case "$evidence" in
        ''|'—'|'-'|no|pending|TBD)
          echo "::error file=$spec::status is done but $ac carries no evidence in ## Verification"
          failed=1
          ;;
      esac
      # A link alone says something was verified, not that today's wording was:
      # a consumer pinned to an older revision reports a pass for text that has
      # since changed, and the row reads exactly like an honest one.
      case "$verified_at" in
        ''|'—'|'-'|no|pending|TBD)
          echo "::error file=$spec::status is done but $ac does not say which revision of this spec its evidence was produced against"
          failed=1
          ;;
      esac
    done < <(ledger "$spec")
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
  echo "$checked spec(s): statuses, ids, placeholders, open questions, supersessions, criteria and verification all clean."
fi
