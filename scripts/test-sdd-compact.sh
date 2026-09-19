#!/usr/bin/env bash
# Behavioral fixtures for the output compactor.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

compact="$PWD/scripts/sdd-compact.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export SDD_RECALL_DIR="$work/recall"
passed=0

fail() { echo "fixture failed: $1" >&2; exit 1; }
ok() { passed=$((passed + 1)); }

expect_contains() {
  local label=$1 needle=$2 haystack=$3
  grep -Fq -e "$needle" <<< "$haystack" || {
    echo "fixture $label did not report: $needle" >&2
    echo "$haystack" >&2
    return 1
  }
}

expect_absent() {
  local label=$1 needle=$2 haystack=$3
  if grep -Fq -e "$needle" <<< "$haystack"; then
    echo "fixture $label should not report: $needle" >&2
    echo "$haystack" >&2
    return 1
  fi
}

# A stub git, so the git filters can be exercised without building repositories.
# It defers rev-parse to the real git, which the compactor uses to find the root.
real_git=$(command -v git)
mkdir -p "$work/bin"
cat > "$work/bin/git" <<EOF
#!/usr/bin/env bash
case "\$1" in
  rev-parse) exec "$real_git" "\$@" ;;
esac
cat "\$GIT_FIXTURE"
EOF
chmod +x "$work/bin/git"

# The command's exit code is the compactor's exit code.
set +e
bash "$compact" sh -c 'exit 3' > /dev/null 2>&1
code=$?
set -e
[ "$code" -eq 3 ] || fail "exit code was $code, expected the command's 3"
ok

# Identical lines collapse to one, with a count.
output=$(bash "$compact" printf 'a\nb\na\nb\nc\n')
expect_contains dedupe 'a  (x2)' "$output" || exit 1
expect_contains dedupe 'c' "$output" || exit 1
ok

# --verbose is the escape hatch: the output arrives untouched.
output=$(bash "$compact" --verbose printf 'a\nb\na\nb\nc\n')
[ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 5 ] || fail '--verbose did not pass the output through'
expect_absent verbose '[full output:' "$output" || exit 1
ok

# A failure is always recoverable in full, without re-running anything.
set +e
output=$(bash "$compact" sh -c 'echo out; echo boom >&2; exit 1' 2>&1)
set -e
expect_contains failure '[full output:' "$output" || exit 1
id=$(sed -n 's/.*sdd-recall\.sh \([^]]*\)].*/\1/p' <<< "$output")
[ -n "$id" ] || fail 'no recall id was printed on failure'
recalled=$(bash "$PWD/scripts/sdd-recall.sh" "$id")
expect_contains recall 'boom' "$recalled" || exit 1
expect_contains recall '--- exit: 1 ---' "$recalled" || exit 1
ok

# Nothing trimmed and nothing wrong means nothing extra to say.
output=$(bash "$compact" printf 'only one line\n')
expect_absent quiet '[full output:' "$output" || exit 1
ok

# Arguments reach the command exactly as written, spaces included.
output=$(bash "$compact" printf '[%s]\n' 'two words')
expect_contains passthrough '[two words]' "$output" || exit 1
ok

export PATH="$work/bin:$PATH"

# git status: the hints a human skims past are the bulk of it.
export GIT_FIXTURE="$work/status.txt"
cat > "$GIT_FIXTURE" <<'EOF'
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   a.txt
	modified:   b.txt

no changes added to commit (use "git add" and/or "git commit -a")
EOF
output=$(bash "$compact" git status)
expect_absent status '(use "git add' "$output" || exit 1
expect_contains status 'modified: a.txt, b.txt' "$output" || exit 1
ok

# git log: one line per commit, not six.
export GIT_FIXTURE="$work/log.txt"
cat > "$GIT_FIXTURE" <<'EOF'
commit 1111111111111111111111111111111111111111
Author: Someone <someone@example.com>
Date:   Mon Jan 1 00:00:00 2024 +0000

    feat: the first thing

commit 2222222222222222222222222222222222222222
Author: Someone <someone@example.com>
Date:   Mon Jan 1 00:00:01 2024 +0000

    fix: the second thing
EOF
output=$(bash "$compact" git log)
expect_contains log '1111111 feat: the first thing' "$output" || exit 1
expect_contains log '2222222 fix: the second thing' "$output" || exit 1
expect_absent log 'someone@example.com' "$output" || exit 1
ok

# git diff: the shape of the change, not its body.
export GIT_FIXTURE="$work/diff.txt"
cat > "$GIT_FIXTURE" <<'EOF'
diff --git a/a.txt b/a.txt
index 111..222 100644
--- a/a.txt
+++ b/a.txt
@@ -1,2 +1,3 @@
 context
+added one
+added two
-removed one
EOF
output=$(bash "$compact" git diff)
expect_contains diff '1 file(s) changed, +2 -1' "$output" || exit 1
expect_contains diff '  a.txt' "$output" || exit 1
expect_absent diff 'added one' "$output" || exit 1
ok

# An SDD script says `ok:` once per check; the count says it once.
cat > "$work/spec-fake.sh" <<'EOF'
#!/usr/bin/env bash
echo "ok: one"
echo "ok: two"
echo "ok: three"
echo "note: something worth reading"
EOF
chmod +x "$work/spec-fake.sh"
output=$(bash "$compact" "$work/spec-fake.sh")
expect_contains script 'ok: 3 check(s) passed' "$output" || exit 1
expect_contains script 'note: something worth reading' "$output" || exit 1
ok

printf '%d sdd-compact fixture(s) passed.\n' "$passed"
