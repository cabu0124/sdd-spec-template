#!/usr/bin/env bash
#
# Assemble a spec's wireframe from the kit's head and the sections drawn for it.
#
#   scripts/spec-wireframe.sh <id>-<slug> sections.html
#   … | scripts/spec-wireframe.sh <id>-<slug>
#
# The head — the fonts, the whole <style> block, the component vocabulary — is
# byte for byte the same in every wireframe this repository will ever draw. An
# agent that writes the file whole has to reproduce all of it verbatim before it
# draws anything, which is the slowest thing it does all run and the least
# useful: a character it gets wrong is a rule that silently stops applying.
#
# So a drawing is only ever the <section> elements, and this puts the kit's own
# head and tail around them. Nothing here decides what a wireframe looks like —
# both halves are lifted from docs/templates/wireframe.html, which belongs to the
# repository and is free to change.
#
# It writes one file and nothing else. See docs/skills/drawing-wireframes/.

set -uo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

TEMPLATE=docs/templates/wireframe.html
HEAD_END='</helmet>'
TAIL_START='</x-dc>'

die() { printf 'spec-wireframe: %s\n' "$1" >&2; exit "${2:-1}"; }

case "${1:-}" in
  --help | -h) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
  '') die "pass the spec directory name, e.g. 007-password-reset" 2 ;;
esac

spec=$1
sections_file=${2:-}

case $spec in
  */* | .*) die "'$spec' is not a spec directory name" 2 ;;
esac

[ -d "specs/$spec" ] || die "specs/$spec does not exist — write spec.md first" 2
[ -f "$TEMPLATE" ] || die "$TEMPLATE is missing, so there is no kit to draw with"

# Both halves are the kit's, marked by tags its own notation already carries.
grep -Fq "$HEAD_END" "$TEMPLATE" || die "$TEMPLATE has no $HEAD_END, so its head cannot be told from its screens"
grep -Fq "$TAIL_START" "$TEMPLATE" || die "$TEMPLATE has no $TAIL_START, so it cannot be closed"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ -n "$sections_file" ]; then
  [ -f "$sections_file" ] || die "$sections_file does not exist" 2
  cat -- "$sections_file" > "$work/sections"
else
  cat > "$work/sections"
fi

[ -s "$work/sections" ] || die "nothing was given to draw, and a wireframe with no screen is not a wireframe" 2
grep -Fq '<section' "$work/sections" || die "what was given holds no <section>, so there is no screen in it" 2

# Handing the head back is the one failure this script exists to prevent, and it
# is silent: the file still opens, carrying the kit's rules twice.
for stray in '<style' "$HEAD_END" '<!DOCTYPE'; do
  if grep -Fq "$stray" "$work/sections"; then
    die "the sections carry $stray — draw the screens only, the kit's head is added here"
  fi
done

{
  awk -v marker="$HEAD_END" '{ print } index($0, marker) { exit }' "$TEMPLATE"
  printf '\n'
  cat "$work/sections"
  printf '\n'
  awk -v marker="$TAIL_START" 'index($0, marker) { found = 1 } found' "$TEMPLATE"
} > "$work/out"

cat "$work/out" > "specs/$spec/wireframe.html"
printf 'wrote specs/%s/wireframe.html — %s lines drawn, %s the kit'"'"'s\n' "$spec" \
  "$(wc -l < "$work/sections" | tr -d ' ')" \
  "$(( $(wc -l < "$work/out" | tr -d ' ') - $(wc -l < "$work/sections" | tr -d ' ') ))"
