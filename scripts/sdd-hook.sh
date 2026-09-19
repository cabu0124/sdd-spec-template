#!/usr/bin/env bash
#
# The PreToolUse hook: it rewrites a shell command to its compact equivalent
# before the agent runs it, so the output reaching the model is already small.
#
#   scripts/sdd-hook.sh claude|copilot|cursor|codex|gemini
#
# It reads the agent's JSON payload on stdin and writes the agent's JSON reply
# on stdout. scripts/sdd-onboard.sh registers it; nothing here is committed.
#
# It fails open, always. Anything it does not fully understand — an unparseable
# payload, an escape sequence, a command it has no filter for — is left to run
# exactly as the agent wrote it. It never blocks a command, and never exits
# non-zero. A hook that guesses is a hook that breaks a session it cannot see.
#
# It also never approves: no permissionDecision is emitted, so the agent's own
# confirmation still applies to the rewritten command. Auto-approving a command
# the user never saw is not this script's call to make.
#
# Only commands on the allowlist below are rewritten, and only when they carry
# no shell metacharacters and no quoting. That is deliberately narrow: this
# parses JSON with awk, and the blast radius of getting that wrong is every
# command the agent runs.

set -uo pipefail

here=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

tool=${1:-}
case $tool in
  claude | copilot | cursor | codex | gemini) ;;
  --help | -h) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
  *) echo "sdd-hook: pass one of claude, copilot, cursor, codex, gemini" >&2; exit 0 ;;
esac

payload=$(cat)

# Gemini expects a decision on every call; the others take silence as "leave it".
passthrough() {
  [ "$tool" = gemini ] && printf '{"decision":"allow"}\n'
  exit 0
}

# One string value out of the payload, by key. Any backslash at all — an escape,
# a path, a newline — is a refusal: unescaping JSON correctly in awk is not a
# bet worth taking, and refusing costs only the compaction.
json_value() {
  printf '%s' "$payload" | awk -v key="$1" '
    { blob = blob $0 }
    END {
      needle = "\"" key "\""
      at = index(blob, needle)
      if (at == 0) exit 1
      rest = substr(blob, at + length(needle))
      sub(/^[ \t]*:[ \t]*/, "", rest)
      if (substr(rest, 1, 1) != "\"") exit 1
      rest = substr(rest, 2)
      value = ""
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c == "\\") exit 1
        if (c == "\"") { print value; exit 0 }
        value = value c
      }
      exit 1
    }
  '
}

# Tool names differ per agent, and some payloads carry none at all.
is_shell_tool() {
  case $1 in
    '' | Bash | bash | shell | terminal | Execute | RunCommand | runInTerminal | run_shell_command) return 0 ;;
    *) return 1 ;;
  esac
}

# The allowlist. A command earns a place here by being one an agent runs
# constantly, and whose output scripts/sdd-compact.sh knows how to condense
# without losing anything the agent needed. Reading a file is absent on purpose:
# truncating what the agent is trying to read is how a wrong edit gets made.
is_compactable() {
  local cmd=$1

  case $cmd in
    *[\|\&\;\<\>\`\$\(\)\"\']* | *'
'*) return 1 ;;
    scripts/sdd-compact.sh* | */sdd-compact.sh*) return 1 ;;
  esac

  # Safe to split: the command holds no metacharacters and no quoting.
  # shellcheck disable=SC2086
  set -- $cmd
  case ${1:-} in
    git)
      case ${2:-} in
        status | log | diff | add | commit | push | pull | fetch | branch | remote) return 0 ;;
      esac
      ;;
    ls | find) return 0 ;;
    scripts/sdd-*.sh | scripts/spec-*.sh | ./scripts/sdd-*.sh | ./scripts/spec-*.sh) return 0 ;;
    bash | sh)
      case ${2:-} in
        scripts/sdd-*.sh | scripts/spec-*.sh) return 0 ;;
      esac
      ;;
  esac
  return 1
}

tool_name=$(json_value tool_name) || tool_name=''
is_shell_tool "$tool_name" || passthrough

command_line=$(json_value command) || passthrough
[ -n "$command_line" ] || passthrough
is_compactable "$command_line" || passthrough

# An absolute path, because the terminal's working directory is not ours to
# assume: it is the workspace root, which in a multi-repo workspace is nowhere
# near scripts/. A relative path there fails with 127 instead of compacting.
compactor="$here/sdd-compact.sh"
case $compactor in
  *[!A-Za-z0-9/._-]*) passthrough ;;
esac

rewritten="$compactor $command_line"

# The value carries no quote and no backslash — is_compactable refused those —
# so it needs no escaping to be a valid JSON string.
case $tool in
  claude | copilot | codex)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":"%s"}}}\n' "$rewritten"
    ;;
  cursor)
    printf '{"updated_input":{"command":"%s"}}\n' "$rewritten"
    ;;
  gemini)
    printf '{"decision":"allow","hookSpecificOutput":{"tool_input":{"command":"%s"}}}\n' "$rewritten"
    ;;
esac

exit 0
