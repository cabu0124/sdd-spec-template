#!/usr/bin/env bash
# Behavioral fixtures for the PreToolUse hook, one per agent format.
#
# The payloads here are frozen on purpose: they are the contract with five
# agents whose schemas are documented unevenly. If one of them changes its
# format, this is where it shows.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

hook="$PWD/scripts/sdd-hook.sh"
passed=0

fail() { echo "fixture failed: $1" >&2; exit 1; }
ok() { passed=$((passed + 1)); }

# Every call must exit 0: a hook that fails takes the agent's turn with it.
run_hook() {
  local tool=$1 payload=$2 output exit_code
  output=$(printf '%s' "$payload" | bash "$hook" "$tool") || exit_code=$?
  exit_code=${exit_code:-0}
  [ "$exit_code" -eq 0 ] || fail "$tool exited $exit_code; the hook must always exit 0"
  printf '%s' "$output"
}

bash_payload() {
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"
}

expect_rewrite() {
  local tool=$1 payload=$2 needle=$3 output
  output=$(run_hook "$tool" "$payload")
  grep -Fq -e "$needle" <<< "$output" || fail "$tool did not rewrite as expected: got '$output'"
  grep -Fq 'permissionDecision' <<< "$output" && fail "$tool auto-approved the rewritten command"
  ok
}

expect_untouched() {
  local tool=$1 payload=$2 label=$3 output
  output=$(run_hook "$tool" "$payload")
  grep -Fq 'sdd-compact.sh' <<< "$output" && fail "$tool rewrote a command it should have left alone: $label"
  ok
}

# Each agent gets its own reply shape.
expect_rewrite claude "$(bash_payload 'git status')" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":"scripts/sdd-compact.sh git status"}}}'
expect_rewrite copilot "$(bash_payload 'git status')" '"updatedInput":{"command":"scripts/sdd-compact.sh git status"}'
expect_rewrite codex "$(bash_payload 'git status')" '"updatedInput":{"command":"scripts/sdd-compact.sh git status"}'
expect_rewrite cursor "$(bash_payload 'git status')" '{"updated_input":{"command":"scripts/sdd-compact.sh git status"}}'
expect_rewrite gemini '{"tool_name":"run_shell_command","tool_input":{"command":"git status"}}' \
  '{"decision":"allow","hookSpecificOutput":{"tool_input":{"command":"scripts/sdd-compact.sh git status"}}}'

# Gemini decides on every call, so silence is not an answer.
output=$(run_hook gemini "$(bash_payload 'cat /etc/hosts')")
[ "$output" = '{"decision":"allow"}' ] || fail "gemini passthrough said '$output', expected an explicit allow"
ok

# A command the shell would re-parse is left alone: the rewrite would change it.
expect_untouched claude "$(bash_payload 'git status | tee out')" 'pipe'
expect_untouched claude "$(bash_payload 'git status && ls')" 'chained'
expect_untouched claude "$(bash_payload 'echo $(git status)')" 'substitution'

# Quoting means escapes, and escapes are refused rather than half-parsed.
expect_untouched claude '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"a message\""}}' 'quoted'

# Nothing to parse, nothing to do.
expect_untouched claude 'not json at all' 'garbage'
expect_untouched claude '' 'empty'
expect_untouched claude '{"tool_name":"Bash","tool_input":{}}' 'no command'

# Not a shell call.
expect_untouched claude '{"tool_name":"read_file","tool_input":{"command":"git status"}}' 'other tool'

# Off the allowlist: reading a file must arrive whole.
expect_untouched claude "$(bash_payload 'cat src/main.rs')" 'cat'
expect_untouched claude "$(bash_payload 'git show HEAD:file')" 'git show'

# Idempotent: feeding the hook its own output must not prefix twice. Two hook
# configurations can be live at once — VS Code reads .github/hooks/ and
# .claude/settings.local.json both.
rewritten=$(run_hook claude "$(bash_payload 'git status')" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p')
[ "$rewritten" = 'scripts/sdd-compact.sh git status' ] || fail "unexpected rewrite: $rewritten"
expect_untouched claude "$(bash_payload "$rewritten")" 'already rewritten'

# An unknown agent is a no-op, not a crash.
expect_untouched unknown-agent "$(bash_payload 'git status')" 'unknown tool'

# --- installation -----------------------------------------------------------
#
# The hook is only useful once onboarding has registered it, and every target
# it writes has to stay out of the repository.

source_root=$PWD
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

(cd "$source_root" && tar --exclude=.git -cf - .) | tar -xf - -C "$work"
git -C "$work" init -q .
(cd "$work" && bash scripts/sdd-onboard.sh claude copilot cursor codex gemini > /dev/null) \
  || fail 'onboarding did not run'

for target in \
  .claude/settings.local.json \
  .github/hooks/sdd-compact.json \
  .cursor/hooks.json \
  .codex/hooks.json \
  .gemini/settings.json; do
  [ -f "$work/$target" ] || fail "onboarding wrote no hook at $target"
  grep -Fq 'sdd-hook.sh' "$work/$target" || fail "$target does not call the hook"
  git -C "$work" check-ignore -q "$target" || fail "$target is generated but not ignored"
  ok
done

(cd "$work" && bash scripts/sdd-onboard.sh --check claude copilot cursor codex gemini > /dev/null) \
  || fail 'regenerating the hooks produced different bytes'
ok

# A hook file someone else wrote is never silently replaced: merging JSON blind
# is how a developer loses their own configuration.
printf '{"hooks":{"PreToolUse":[{"type":"command","command":"mine"}]}}\n' > "$work/.cursor/hooks.json"
if (cd "$work" && bash scripts/sdd-onboard.sh cursor > /dev/null 2>&1); then
  fail 'onboarding overwrote an unmanaged hook file'
fi
grep -Fq 'mine' "$work/.cursor/hooks.json" || fail 'an unmanaged hook file was modified'
ok

printf '%d sdd-hook fixture(s) passed.\n' "$passed"
