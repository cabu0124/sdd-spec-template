#!/usr/bin/env bash
# Behavioral fixtures for the wireframe assembler.
#
# What matters is that the kit's head arrives byte for byte — the point of not
# asking an agent to retype it — and that a drawing which carries the head back
# is refused rather than written twice.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

assemble="$PWD/scripts/spec-wireframe.sh"
template="$PWD/docs/templates/wireframe.html"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
fail() { echo "fixture failed: $1" >&2; exit 1; }
ok() { passed=$((passed + 1)); }

# A repository of its own, so the fixture never writes into this one.
mkdir -p "$work/specs/007-a-spec" "$work/docs/templates" "$work/scripts"
cd "$work"
git init -q .
cp "$assemble" scripts/spec-wireframe.sh
cp "$template" docs/templates/wireframe.html
printf '# Spec 007\n' > specs/007-a-spec/spec.md

run() { bash scripts/spec-wireframe.sh "$@"; }

printf '<section class="dv-turn" id="t1">\n<div>drawn</div>\n</section>\n' > sections.html

output=$(run 007-a-spec sections.html 2>&1) || fail "assembling exited non-zero: $output"
[ -f specs/007-a-spec/wireframe.html ] || fail 'no wireframe was written'
ok

# The head is the kit's, unchanged. A generator that rewrites it is the problem.
head_of() { awk '{ print } index($0, "</helmet>") { exit }' "$1"; }
diff <(head_of docs/templates/wireframe.html) <(head_of specs/007-a-spec/wireframe.html) > /dev/null \
  || fail 'the assembled head differs from the kit'
ok

grep -Fq 'drawn' specs/007-a-spec/wireframe.html || fail 'the drawing did not reach the file'
grep -Fq '</html>' specs/007-a-spec/wireframe.html || fail 'the document was not closed'
ok

# The head appears once. Twice means the sections carried it and nobody noticed.
[ "$(grep -Fc '</helmet>' specs/007-a-spec/wireframe.html)" = 1 ] \
  || fail 'the head landed in the file more than once'
ok

# Sections from stdin, for an agent that never puts the markup on disk first.
rm specs/007-a-spec/wireframe.html
run 007-a-spec < sections.html > /dev/null || fail 'stdin was not accepted'
[ -f specs/007-a-spec/wireframe.html ] || fail 'nothing was written from stdin'
ok

# A drawing that carries the head back is refused, loudly. It is the failure the
# script exists to prevent, and the assembled file would still have opened.
cat docs/templates/wireframe.html > with-head.html
run 007-a-spec with-head.html > /dev/null 2>&1 && fail 'sections carrying the kit head were accepted'
ok

printf '<div>no section here</div>\n' > empty.html
run 007-a-spec empty.html > /dev/null 2>&1 && fail 'a drawing with no <section> was accepted'
ok

: > nothing.html
run 007-a-spec nothing.html > /dev/null 2>&1 && fail 'an empty drawing was accepted'
ok

run 404-not-a-spec sections.html > /dev/null 2>&1 && fail 'an unknown spec directory was accepted'
ok

# Paths are directory names, never traversals.
run ../elsewhere sections.html > /dev/null 2>&1 && fail 'a path was accepted as a spec name'
ok

# The markers belong to the kit, so a kit without them fails rather than guesses.
printf '<html>no markers here</html>\n' > docs/templates/wireframe.html
run 007-a-spec sections.html > /dev/null 2>&1 && fail 'a kit with no head marker was accepted'
ok

printf '%d spec-wireframe fixture(s) passed.\n' "$passed"
