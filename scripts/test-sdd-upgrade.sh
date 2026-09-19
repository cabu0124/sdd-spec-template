#!/usr/bin/env bash
# Behavioral fixtures for the template upgrade.
#
# It builds a throwaway template with two published versions and a repository
# built from the first, because that is the only way to exercise what matters:
# what an upgrade does to a file the repository edited, and to one it did not.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

upgrade="$PWD/scripts/sdd-upgrade.sh"
lib="$PWD/scripts/sdd-lib.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
fail() { echo "fixture failed: $1" >&2; exit 1; }
ok() { passed=$((passed + 1)); }

template="$work/template"
repo="$work/repo"

manifest() {
  cat <<'EOF'
managed:
  - scripts/tool.sh
  - docs/commands/thing.md
  - .sdd/manifest.yml
seeded:
  - AGENTS.md
ignored:
  - LICENSE
blocks:
  - AGENTS.md sdd:rule1
EOF
}

# --- a template with two published versions ---------------------------------

mkdir -p "$template/scripts" "$template/docs/commands" "$template/.sdd"
git -C "$template" init -q .
git -C "$template" config user.email t@e.com
git -C "$template" config user.name T

manifest > "$template/.sdd/manifest.yml"
printf '#!/usr/bin/env bash\necho v1\n' > "$template/scripts/tool.sh"
chmod +x "$template/scripts/tool.sh"
printf 'the first thing\n' > "$template/docs/commands/thing.md"
printf '# AGENTS\n\n<!-- sdd:rule1:start -->\nrule one, v1\n<!-- sdd:rule1:end -->\n\n## Product\n\n<fill me>\n' \
  > "$template/AGENTS.md"
printf 'a licence\n' > "$template/LICENSE"
git -C "$template" add -A
git -C "$template" commit -qm v1
git -C "$template" tag v1.0.0

printf '#!/usr/bin/env bash\necho v2\n' > "$template/scripts/tool.sh"
printf 'the second thing\n' > "$template/docs/commands/thing.md"
printf 'brand new\n' > "$template/docs/commands/added.md"
printf '# AGENTS\n\n<!-- sdd:rule1:start -->\nrule one, v2\n<!-- sdd:rule1:end -->\n\n## Product\n\n<fill me>\n' \
  > "$template/AGENTS.md"
{ manifest; printf '  - docs/commands/added.md\n'; } > "$template/.sdd/manifest.yml"
# The added file belongs under managed, so rewrite the list properly.
cat > "$template/.sdd/manifest.yml" <<'EOF'
managed:
  - scripts/tool.sh
  - docs/commands/thing.md
  - docs/commands/added.md
  - .sdd/manifest.yml
seeded:
  - AGENTS.md
ignored:
  - LICENSE
blocks:
  - AGENTS.md sdd:rule1
EOF
git -C "$template" add -A
git -C "$template" commit -qm v2
git -C "$template" tag v1.1.0

# --- a repository built from v1.0.0 -----------------------------------------

mkdir -p "$repo/scripts" "$repo/docs/commands" "$repo/.sdd"
git -C "$repo" init -q .
git -C "$repo" config user.email r@e.com
git -C "$repo" config user.name R
git -C "$template" archive v1.0.0 | tar -x -C "$repo"
cp "$lib" "$repo/scripts/sdd-lib.sh"
cp "$upgrade" "$repo/scripts/sdd-upgrade.sh"
# The repository's own content, which an upgrade must never touch.
mkdir -p "$repo/specs/001-mine"
printf 'my spec\n' > "$repo/specs/001-mine/spec.md"
printf '# AGENTS\n\n<!-- sdd:rule1:start -->\nrule one, v1\n<!-- sdd:rule1:end -->\n\n## Product\n\nMy actual product.\n' \
  > "$repo/AGENTS.md"
git -C "$repo" add -A
git -C "$repo" commit -qm start

run_upgrade() { (cd "$repo" && bash scripts/sdd-upgrade.sh "$@"); }

# Provenance is worked out, not guessed: v1.0.0 is what this repository matches.
output=$(run_upgrade --adopt --source "$template" 2>&1) || fail "--adopt exited non-zero: $output"
grep -Fq 'v1.0.0' <<< "$output" || fail "--adopt did not detect v1.0.0: $output"
[ -f "$repo/.sdd/template.yml" ] || fail '--adopt wrote no .sdd/template.yml'
[ -f "$repo/.sdd/template.lock" ] || fail '--adopt wrote no .sdd/template.lock'
grep -q '^version: v1.0.0$' "$repo/.sdd/template.yml" || fail 'the pinned version is not v1.0.0'
ok

# The pin holds: with no --to, the target is the recorded version, and there is
# nothing to do.
output=$(run_upgrade 2>&1) && exit_code=0 || exit_code=$?
[ "${exit_code:-0}" -eq 0 ] || fail "a repository on its pinned version reported work to do: $output"
grep -Fq 'Up to date' <<< "$output" || fail "expected 'Up to date', got: $output"
ok

# A newer version is only looked at when asked for.
output=$(run_upgrade --to v1.1.0 2>&1) && exit_code=0 || exit_code=$?
[ "${exit_code:-0}" -eq 1 ] || fail "--check should exit 1 when work is pending, exited ${exit_code:-0}"
grep -Fq 'update    scripts/tool.sh' <<< "$output" || fail "tool.sh was not reported as an update: $output"
grep -Fq 'new       docs/commands/added.md' <<< "$output" || fail "added.md was not reported as new: $output"
grep -Fq 'block     AGENTS.md' <<< "$output" || fail "the rule1 block was not reported: $output"
ok

# An edited managed file is reported and left alone — never merged.
printf '#!/usr/bin/env bash\necho mine\n' > "$repo/docs/commands/thing.md"
output=$(run_upgrade --to v1.1.0 2>&1) || true
grep -Fq 'conflict  docs/commands/thing.md' <<< "$output" || fail "an edited file was not reported as a conflict: $output"
ok

output=$(run_upgrade --to v1.1.0 --diff 2>&1) || true
grep -Fq 'the second thing' <<< "$output" || fail "--diff did not show the incoming change: $output"
ok

# Applying writes the working tree and nothing else.
before=$(git -C "$repo" rev-parse HEAD)
output=$(run_upgrade --to v1.1.0 --apply 2>&1) || fail "--apply exited non-zero: $output"
[ "$(git -C "$repo" rev-parse HEAD)" = "$before" ] || fail '--apply committed something'
grep -Fq 'echo v2' "$repo/scripts/tool.sh" || fail 'tool.sh was not updated'
[ -x "$repo/scripts/tool.sh" ] || fail 'tool.sh lost its executable bit'
[ -f "$repo/docs/commands/added.md" ] || fail 'the new file was not written'
grep -Fq 'echo mine' "$repo/docs/commands/thing.md" || fail 'a locally edited file was overwritten'
ok

# Seeded files keep their content; only the marked block moves.
grep -Fq 'My actual product.' "$repo/AGENTS.md" || fail 'a seeded file lost the product content'
grep -Fq 'rule one, v2' "$repo/AGENTS.md" || fail 'the rule1 block was not refreshed'
ok

# The repository's own files are never in scope.
grep -Fq 'my spec' "$repo/specs/001-mine/spec.md" || fail 'a spec was touched'
ok

grep -q '^version: v1.1.0$' "$repo/.sdd/template.yml" || fail 'the pin was not moved to v1.1.0'
ok

# The lock records what the template delivered, not what the repository holds.
# Get this backwards and the next upgrade overwrites every local edit.
locked=$(awk '$2 == "docs/commands/thing.md" { print $1 }' "$repo/.sdd/template.lock")
[ "$locked" = "$(git -C "$template" rev-parse v1.0.0:docs/commands/thing.md)" ] \
  || fail 'the lock moved for a file that was never applied'
ok

# And the conflict is still a conflict on the next run, rather than quietly
# becoming the new baseline.
output=$(run_upgrade 2>&1) || true
grep -Fq 'conflict  docs/commands/thing.md' <<< "$output" || fail "the conflict stopped being reported: $output"
ok

output=$(run_upgrade --list 2>&1) || fail '--list exited non-zero'
grep -Fq 'v1.1.0' <<< "$output" || fail "--list did not report the versions: $output"
ok

# A repository can take a managed file over for good. A deliberate divergence is
# a decision once, not a warning on every run for ever.
printf 'keep:\n  - docs/commands/thing.md\n' >> "$repo/.sdd/template.yml"
output=$(run_upgrade 2>&1) && exit_code=0 || exit_code=$?
[ "${exit_code:-0}" -eq 0 ] || fail "a repository with only kept files still reported work to do: $output"
grep -Fq 'kept      docs/commands/thing.md' <<< "$output" || fail "the kept file was not reported as kept: $output"
grep -Fq 'conflict  docs/commands/thing.md' <<< "$output" && fail 'a kept file was still reported as a conflict'
ok

# The list is the repository's, so rewriting the config must not eat it.
run_upgrade --to v1.1.0 --apply > /dev/null
grep -Fq '  - docs/commands/thing.md' "$repo/.sdd/template.yml" || fail 'keep: was lost when the config was rewritten'
grep -Fq 'echo mine' "$repo/docs/commands/thing.md" || fail 'a kept file was overwritten by --apply'
ok

# --- this template's own manifest -------------------------------------------
#
# Every versioned file is classified, or a file added later silently reaches
# nobody. Only the template answers for this: a repository built from it has
# files of its own — its specs, its skills, its product docs — that are absent
# from the manifest on purpose, and listing them there would be wrong.
if [ -f .sdd/manifest.yml ] && [ ! -f .sdd/template.yml ]; then
  unclassified=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case $path in specs/* | .sdd/template.yml | .sdd/template.lock) continue ;; esac
    grep -Fq "  - $path" .sdd/manifest.yml && continue
    echo "not classified in .sdd/manifest.yml: $path" >&2
    unclassified=1
  done < <(git ls-files)
  [ "$unclassified" -eq 0 ] || fail 'the manifest does not cover every versioned file'
fi
ok

printf '%d sdd-upgrade fixture(s) passed.\n' "$passed"
