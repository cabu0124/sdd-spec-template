#!/usr/bin/env bash
# Behavioral fixtures for model suggestions: every command declares how much
# reasoning it is worth, every generated adapter reports that tier and its
# suggested model to the user, and nothing anywhere sets a model.
#
# It discovers the commands by tier rather than naming them, so the same file
# holds in a repository whose command set is different.

set -euo pipefail

if root=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$root"
fi

source_root=$PWD
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The generator runs against a repository, so give it a copy of this one rather
# than a clone: the point is to test the working tree, not the last commit.
(cd "$source_root" && tar --exclude=.git -cf - .) | tar -xf - -C "$work"
git -C "$work" init -q .

tools='claude copilot cursor gemini codex'

generate() { (cd "$work" && env "$@" bash scripts/sdd-onboard.sh $tools >/dev/null 2>&1); }

# Where each tool's wrapper for one command lands.
adapter() {
  case "$1" in
    claude)  printf '.claude/commands/sdd-%s.md' "$2" ;;
    copilot) printf '.github/prompts/sdd-%s.prompt.md' "$2" ;;
    cursor)  printf '.cursor/commands/sdd-%s.md' "$2" ;;
    gemini)  printf '.gemini/commands/sdd-%s.toml' "$2" ;;
    codex)   printf '.codex/prompts/sdd-%s.md' "$2" ;;
  esac
}

# The suggestion an adapter carries, and the tier it reports. Both are read out
# of the body, because that is the only place either one exists now.
suggested() { sed -n 's/.*suggested model for it is \*\*\([^*]*\)\*\*.*/\1/p' "$work/$1" | head -n1; }
tier_in()   { sed -n 's/.*rated `\([a-z]*\)` reasoning.*/\1/p' "$work/$1" | head -n1; }

# The first command declaring a tier, or empty when this repository has none.
command_at() {
  local tier=$1 file name
  for file in "$work"/docs/commands/*.md; do
    name=$(basename "$file" .md)
    [ "$(sed -n 's/^Reasoning:[[:space:]]*//p' "$file" | head -n1 | awk '{ print $1 }')" = "$tier" ] || continue
    printf '%s' "$name"
    return 0
  done
  return 0
}

high_cmd=$(command_at high)
standard_cmd=$(command_at standard)
mechanical_cmd=$(command_at mechanical)

[ -n "$high_cmd" ] || { echo 'no command declares Reasoning: high' >&2; exit 1; }
[ -n "$mechanical_cmd" ] || { echo 'no command declares Reasoning: mechanical' >&2; exit 1; }

generate SDD_MODEL_UNUSED=1

# Nothing generated sets a model. This is the whole point: the suggestion is
# reported to the user, who decides. A `model:` field anywhere is this rule
# broken.
for tool in $tools; do
  target=$(adapter "$tool" "$high_cmd")
  grep -qE '^model:|^model =' "$work/$target" \
    && { echo "$target pins a model" >&2; exit 1; }
done

# Every command, in every tool, reports its tier and waits for the user.
for file in "$work"/docs/commands/*.md; do
  name=$(basename "$file" .md)
  for tool in $tools; do
    target=$(adapter "$tool" "$name")
    [ -f "$work/$target" ] || { echo "no adapter generated: $target" >&2; exit 1; }
    [ -n "$(tier_in "$target")" ] || { echo "no tier reported in $target" >&2; exit 1; }
    grep -q 'stop and wait' "$work/$target" \
      || { echo "$target does not stop for the user" >&2; exit 1; }
  done
done

# The tiers suggest different models, or the suggestion says nothing.
high=$(suggested "$(adapter copilot "$high_cmd")")
mechanical=$(suggested "$(adapter copilot "$mechanical_cmd")")
[ -n "$high" ] || { echo 'no model suggested for the high tier' >&2; exit 1; }
[ "$high" != "$mechanical" ] || { echo "$high_cmd and $mechanical_cmd suggested the same model" >&2; exit 1; }

if [ -n "$standard_cmd" ]; then
  standard=$(suggested "$(adapter copilot "$standard_cmd")")
  { [ "$standard" != "$high" ] && [ "$standard" != "$mechanical" ]; } \
    || { echo "$standard_cmd did not suggest its own tier" >&2; exit 1; }
fi

# Each tool names models its own way, so the same tier suggests each tool's own
# catalogue rather than one string written into all of them.
[ -n "$(suggested "$(adapter claude "$high_cmd")")" ] \
  || { echo "no suggestion in the claude adapter for $high_cmd" >&2; exit 1; }

# A tier is retargeted for one tool without touching the others.
generate SDD_MODEL_CLAUDE_HIGH=fixture-claude-high
[ "$(suggested "$(adapter claude "$high_cmd")")" = fixture-claude-high ] \
  || { echo 'SDD_MODEL_CLAUDE_HIGH did not reach the claude adapter' >&2; exit 1; }
[ "$(suggested "$(adapter copilot "$high_cmd")")" = "$high" ] \
  || { echo 'a claude-only override leaked into copilot' >&2; exit 1; }

# The generic override is the shortcut for when the tools do agree.
generate SDD_MODEL_HIGH=fixture-high
for tool in claude copilot codex; do
  [ "$(suggested "$(adapter "$tool" "$high_cmd")")" = fixture-high ] \
    || { echo "SDD_MODEL_HIGH did not reach $tool" >&2; exit 1; }
done

# The more specific override wins over the generic one.
generate SDD_MODEL_HIGH=fixture-generic SDD_MODEL_COPILOT_HIGH=fixture-copilot
[ "$(suggested "$(adapter copilot "$high_cmd")")" = fixture-copilot ] \
  || { echo 'the per-tool override did not win over the generic one' >&2; exit 1; }
[ "$(suggested "$(adapter claude "$high_cmd")")" = fixture-generic ] \
  || { echo 'claude did not fall back to the generic override' >&2; exit 1; }

# The committed table is where a team sets this, so it has to be what the
# generator reads when nothing is exported.
printf 'claude:\n  high: from-config-claude\ncopilot:\n  high: From Config Copilot\n' \
  > "$work/.sdd/models.yml"
generate SDD_MODEL_UNUSED=1
[ "$(suggested "$(adapter claude "$high_cmd")")" = from-config-claude ] \
  || { echo '.sdd/models.yml was not read for claude' >&2; exit 1; }
[ "$(suggested "$(adapter copilot "$high_cmd")")" = 'From Config Copilot' ] \
  || { echo '.sdd/models.yml was not read for copilot, or its spaces were lost' >&2; exit 1; }

# A tool the table does not name reports the tier and suggests nothing, rather
# than a model nobody chose.
[ -z "$(suggested "$(adapter cursor "$high_cmd")")" ] \
  || { echo 'cursor suggested a model with no table for it' >&2; exit 1; }
[ "$(tier_in "$(adapter cursor "$high_cmd")")" = high ] \
  || { echo 'cursor stopped reporting the tier once it had no table' >&2; exit 1; }

# A tier the table does not name still falls back, so a partial table is usable.
[ -n "$(suggested "$(adapter claude "$mechanical_cmd")")" ] \
  || { echo 'a tier absent from the table did not fall back to a default' >&2; exit 1; }

# The environment is the one-off on top of the committed table, not the reverse.
generate SDD_MODEL_CLAUDE_HIGH=from-env
[ "$(suggested "$(adapter claude "$high_cmd")")" = from-env ] \
  || { echo 'the environment did not win over .sdd/models.yml' >&2; exit 1; }

# A command that declares no tier still reports one.
printf '# /sdd-untiered\n\nArgument: none.\n' > "$work/docs/commands/untiered.md"
generate SDD_MODEL_UNUSED=1
[ "$(tier_in "$(adapter copilot untiered)")" = standard ] \
  || { echo 'a command with no Reasoning line did not default to standard' >&2; exit 1; }
rm "$work/docs/commands/untiered.md"

# Codex reads AGENTS.md itself, so onboarding it writes no second instructions file.
[ -f "$work/CODEX.md" ] && { echo 'codex got a redundant instructions file' >&2; exit 1; }

# Every role under docs/agents/ becomes a subagent for the tools that have one.
# Without this the directory can quietly empty out and nothing would ever be
# delegated — which is how reading ends up back in the main thread.
agent_count=0
for file in "$work"/docs/agents/*.md; do
  [ -f "$file" ] || continue
  agent_count=$((agent_count + 1))
  slug=$(basename "$file" .md)
  for target in ".claude/agents/$slug.md" ".github/chatmodes/$slug.chatmode.md"; do
    [ -f "$work/$target" ] || { echo "no subagent generated: $target" >&2; exit 1; }
  done
  # The description is the mechanism, not documentation: it is what makes a tool
  # reach for the subagent on its own.
  grep -q '^description:' "$file" \
    || { echo "$file declares no description, so nothing will ever invoke it" >&2; exit 1; }
done
[ "$agent_count" -gt 0 ] \
  || { echo 'docs/agents/ defines no roles, so no subagent is ever generated' >&2; exit 1; }

echo '15 model-suggestion and delegation fixture(s) passed.'
