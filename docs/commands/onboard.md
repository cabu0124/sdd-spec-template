# /sdd-onboard — set up your agent tool for this repo

**Goal.** Generate the local adapter, command, agent, skill and standard files
required by the agent tools a developer uses. The generated files point to
`AGENTS.md`, `docs/commands/`, `docs/agents/`, `docs/skills/` and
`docs/standards/`; they contain no product decisions of their own.

Runs per developer, not per repository. Re-run it after the `Rule 1` block in
`AGENTS.md` changes or when adding another tool.

Argument: one or more of `claude`, `cursor`, `copilot`, `gemini`; empty means ask
once with multi-select.

## First run

On a fresh clone the slash command does not exist. Point the agent here:

> Follow `docs/commands/onboard.md`.

## Ask only

Which supported tools the developer uses. Native tools that already read
`AGENTS.md` and have no command system need no generated files.

## Steps

1. Run the generator once with every selected tool:

   ```bash
   scripts/sdd-onboard.sh claude cursor copilot gemini
   ```

   Omit tools the developer does not use. Do not reproduce its YAML, TOML or
   Markdown generation in the conversation.
2. Run the same selection with `--check`. It must report that every adapter and
   command is current:

   ```bash
   scripts/sdd-onboard.sh --check claude cursor copilot gemini
   ```

3. Confirm the generated paths are ignored with `git check-ignore`. The shipped
   `.gitignore` covers `CLAUDE.md`, `GEMINI.md`, `.claude/`, `.cursor/`,
   `.gemini/`, `.github/copilot-instructions.md`, `.github/prompts/`,
   `.github/chatmodes/`, `.github/skills/` and `.github/instructions/`.
4. If the generator refuses an existing file, stop. It only updates files with
   its management marker; merge a hand-written customization deliberately
   instead of overwriting it.
5. Report the generated paths per tool. A team that wants to share an adapter
   may remove its ignore rule and commit it; the generator remains its source.

## What the generator guarantees

- The `Rule 1` block is copied byte-for-byte from `AGENTS.md` into each adapter.
- One command wrapper is derived from every file under `docs/commands/`.
- One subagent or chat mode is derived from every file under `docs/agents/`, for
  the tools that have one (`claude`, `copilot`). `cursor` and `gemini` have no
  native subagent concept and are skipped rather than approximated.
- One skill directory is copied as-is from every `docs/skills/<slug>/SKILL.md`,
  for the tools with a native skill directory (`claude`, `copilot`).
- One scoped rule is derived from every file under `docs/standards/`, for the
  tools with per-file scoping (`copilot`'s `applyTo`, `cursor`'s `globs`).
  `claude` and `gemini` have no such mechanism; a standard that must always
  apply belongs in `AGENTS.md` instead.
- Re-running with the same inputs produces the same bytes.
- `--check` writes nothing and reports missing or stale generated files.
- A file without the management marker is never overwritten.

The supported adapters are `CLAUDE.md`, `GEMINI.md`,
`.github/copilot-instructions.md` and `.cursor/rules/00-spec-first.mdc`. Command
wrappers are generated under each tool's native command directory. Tools that
read `AGENTS.md` natively can follow `docs/commands/<name>.md` directly.

| Category | Source | claude | copilot | cursor | gemini |
| --- | --- | --- | --- | --- | --- |
| Command | `docs/commands/*.md` | `.claude/commands/` | `.github/prompts/` | `.cursor/commands/` | `.gemini/commands/` |
| Agent | `docs/agents/*.md` | `.claude/agents/` | `.github/chatmodes/` | — | — |
| Skill | `docs/skills/<slug>/SKILL.md` | `.claude/skills/` | `.github/skills/` | — | — |
| Standard | `docs/standards/*.md` | — | `.github/instructions/` | `.cursor/rules/` | — |

## Does it actually work?

Generation tests formatting; behavior still needs a smoke test:

- Ask the agent to write a plan or implement a spec. It must say that plans,
  tasks and code belong in the consuming repository and stop.
- Ask for a REST endpoint in a requirement. It must preserve the behavior while
  leaving the endpoint decision to each consumer's plan.

## Writes

Generated adapters, command wrappers, agent, skill and standard files only. No
product content or spec.

## Stops when

`--check` passes for every selected tool and the behavior smoke test follows
Rule 1. Next: `/sdd-init new|existing`.
