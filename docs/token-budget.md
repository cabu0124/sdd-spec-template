# Token budget — why command output is condensed

An agent reads the output of every command it runs, and pays for every line of
it. A `sdd-check` run that prints 300 lines to say "everything passed" is 300
lines of context bought to learn one thing. This is the machinery that stops
that, and the rules it follows.

The idea is not ours: [RTK](https://github.com/rtk-ai/rtk) proved it works. What
is ours is the shape — no binary to install, no telemetry, and a rewrite
allowlist narrow enough to audit in one sitting.

## The three pieces

| File | Does |
| --- | --- |
| `scripts/sdd-compact.sh` | Runs a command and condenses its output. The exit code is the command's own. |
| `scripts/sdd-recall.sh` | Keeps the full output of anything that failed or was trimmed, under `.sdd/recall/`. |
| `scripts/sdd-hook.sh` | The agent's PreToolUse hook: rewrites a command to run through the compactor. |

`scripts/sdd-lib.sh` holds the four primitives all of them share: drop, group,
deduplicate, truncate.

## What gets condensed

| Command | Becomes |
| --- | --- |
| `git status` | The branch and the paths, grouped by state. The `(use "git add"...)` hints go. |
| `git log` | One line per commit: short sha and subject. |
| `git diff` | A count of files, `+`/`-` totals, and the file list. The body goes to recall. |
| `git add/commit/push/pull/fetch` | One `ok:` line, when it succeeded. |
| `scripts/sdd-*.sh`, `scripts/spec-*.sh` | The `ok:` lines collapse to a count. Errors and notes stay. |
| anything else | Identical lines collapse; the middle of a long output is elided. |

`scripts/sdd-check.sh` condenses itself: a passing check is one line, a failing
one prints its output and a recall id.

## Adding a filter

In `scripts/sdd-compact.sh`: write a `filter_<thing>` function that reads stdin
and writes stdout, then give it a case in `apply_filter`. Add a fixture to
`scripts/test-sdd-compact.sh` — it stubs `git` on `PATH`, so a filter can be
tested without building a repository.

Two rules. A filter never re-runs the command and never rewrites its arguments:
it only post-processes what was printed. And a filter never drops the only copy
of something — that is what recall is for.

## The rewrite hook

`scripts/sdd-onboard.sh` registers it per tool. Every target is gitignored,
because a hook is a developer's local wiring:

| Tool | File | Event |
| --- | --- | --- |
| claude | `.claude/settings.local.json` | `PreToolUse` |
| copilot | `.github/hooks/sdd-compact.json` | `PreToolUse` |
| cursor | `.cursor/hooks.json` | `preToolUse` |
| codex | `.codex/hooks.json` | `PreToolUse` |
| gemini | `.gemini/settings.json` | `BeforeTool` |

The codex and gemini schemas are not publicly documented; they were derived from
RTK's implementation. The frozen payloads in `scripts/test-sdd-hook.sh` are where
a schema change shows up first, and the failure mode is benign: an unrecognised
payload is passed through uncompacted.

### What the hook refuses to do

- **It never blocks.** Every path exits 0. A hook that fails takes the agent's
  turn with it.
- **It never approves.** No `permissionDecision` is emitted, so the agent's own
  confirmation still applies to the rewritten command. Auto-approving a command
  the user never saw is not the hook's call.
- **It never rewrites what it cannot read.** Any backslash in the JSON value,
  any shell metacharacter, any quoting — refused, and the command runs as
  written. Parsing JSON with `awk` is only safe because the accepted subset is
  this small.
- **It never touches file reads.** `cat`, `head` and `tail` are off the
  allowlist on purpose.

Only these are rewritten: `git status|log|diff|add|commit|push|pull|fetch|branch|remote`,
`ls`, `find`, and this repository's own `scripts/sdd-*.sh` and `scripts/spec-*.sh`.

### One known limitation

The hook replaces the tool input's `command` and nothing else. An agent that
passes other fields alongside it — a description, a background flag — sees them
reset to their defaults on a rewritten command. The allowlist is all
short-lived, foreground commands, which is why this is acceptable rather than
merely known.

## Turning it off

Per command, in any tool: run the command without the `scripts/sdd-compact.sh`
prefix, or pass `--verbose`. Per repository: `scripts/sdd-onboard.sh` writes the
hook files, so deleting them stops the rewriting until it is run again.

## The recall store

`.sdd/recall/`, gitignored, `0700`, capped at 20 entries of 1 MiB. It holds
whatever the commands printed — which can include anything a command printed
that it should not have. `scripts/sdd-recall.sh --prune` empties it.

## Security note

The hook runs a script in `scripts/`. An agent that can edit that directory can
edit what the hook executes, and then execute it. Keep `scripts/` on the "never
touch" list in `AGENTS.md`, and review changes to it the way you would review
anything else that runs without being asked.
