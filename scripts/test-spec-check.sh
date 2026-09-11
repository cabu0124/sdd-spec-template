#!/usr/bin/env bash
# Behavioral fixtures for the shared spec validator.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

checker="$PWD/scripts/spec-check.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

write_spec() {
  local name=$1 status=$2 requirements=$3 criteria=$4 questions=$5 metadata=${6:-}
  local dir="$work/$name"
  mkdir -p "$dir"
  cat > "$dir/spec.md" <<EOF
# Spec ${name%%-*} - Fixture

- **Status:** $status
$metadata
## Requirements

$requirements

## Acceptance criteria

$criteria

## Open questions

$questions
EOF
}

expect_pass() {
  local name=$1
  if ! bash "$checker" --root "$work" "$work/$name" >/dev/null; then
    echo "fixture should pass: $name" >&2
    return 1
  fi
}

expect_fail() {
  local name=$1 message=$2 output
  output="$work/$name.output"
  if bash "$checker" --root "$work" "$work/$name" >"$output" 2>&1; then
    echo "fixture should fail: $name" >&2
    return 1
  fi
  if ! grep -Fq "$message" "$output"; then
    echo "fixture $name did not report: $message" >&2
    cat "$output" >&2
    return 1
  fi
}

write_spec 001-valid approved \
  '- **R1** - Valid behavior.' \
  '- [ ] **AC1** (R1) - Observable result.' \
  ''
expect_pass 001-valid

write_spec 002-draft-open draft \
  '- **R1** - Draft behavior.' \
  '- [ ] **AC1** (R1) - Draft result.' \
  '- [ ] A decision is still open.'
expect_pass 002-draft-open

write_spec 003-missing-ac review \
  $'- **R1** - Covered.\n- **R2** - Uncovered.' \
  '- [ ] **AC1** (R1) - First result.' \
  ''
expect_fail 003-missing-ac 'R2 has no acceptance criterion'

write_spec 004-malformed-ac review \
  '- **R1** - Valid behavior.' \
  '- [ ] **AC1** - Missing requirement link.' \
  ''
expect_fail 004-malformed-ac 'every acceptance criterion must name one or more requirements'

write_spec 005-unknown-requirement review \
  '- **R1** - Valid behavior.' \
  '- [ ] **AC1** (R2) - Wrong reference.' \
  ''
expect_fail 005-unknown-requirement 'names R2, which is not a requirement'

write_spec 006-duplicates review \
  $'- **R1** - First.\n- **R1** - Duplicate.' \
  $'- [ ] **AC1** (R1) - First.\n- [ ] **AC1** (R1) - Duplicate.' \
  ''
expect_fail 006-duplicates 'duplicate requirement id(s): R1'

write_spec 007-done-open done \
  '- **R1** - Delivered behavior.' \
  '- [ ] **AC1** (R1) - Delivered result.' \
  '- [ ] Still undecided.'
expect_fail 007-done-open 'status is done but ## Open questions'

write_spec 008-multi-done done \
  '- **R1** - Integrated behavior.' \
  '- [ ] **AC1** (R1) - Integrated result.' \
  '' \
  '- **Consumers:** repo-a · repo-b'
expect_fail 008-multi-done 'more than one consumer, but it has no ## Verification ledger'

write_spec 009-owner-superseded superseded \
  '- **R1** - Old behavior.' \
  '- [ ] **AC1** (R1) - Old result.' \
  '' \
  '- **Superseded by:** 010-successor'
expect_fail 009-owner-superseded "which is not a spec in $work/"

write_spec 010-mirror-superseded superseded \
  '- **R1** - Old mirrored behavior.' \
  '- [ ] **AC1** (R1) - Old mirrored result.' \
  '' \
  '- **Superseded by:** 011-upstream-only'
printf '%s\n' 'source:' '  id: 004-old' > "$work/010-mirror-superseded/spec.link.yml"
expect_pass 010-mirror-superseded

echo '10 spec-check fixture(s) passed.'
