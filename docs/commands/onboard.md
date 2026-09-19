# /sdd-onboard — set up your agent tool for this repo

**Goal.** Generate the local adapter, command, agent, skill and standard files
required by the agent tools a developer uses. The generated files point to
`AGENTS.md`, `docs/commands/`, `docs/agents/`, `docs/skills/` and
`docs/standards/`; they contain no product decisions of their own.

Runs per developer, not per repository. Re-run it after the `Rule 1` block in
`AGENTS.md` changes or when adding another tool.

Argument: one or more of `claude`, `cursor`, `copilot`, `gemini`, `codex`; empty
means ask
once with multi-select.

Reasoning: mechanical — a deterministic generator writes every file.

## First run

On a fresh clone the slash command does not exist. Point the agent here:

> Follow `docs/commands/onboard.md`.

## Ask only

Which supported tools the developer uses. Native tools that already read
`AGENTS.md` and have no command system need no generated files.

## Steps

1. Run the generator once with every selected tool:

   ```bash
   scripts/sdd-onboard.sh claude cursor copilot gemini codex
   ```

   Omit tools the developer does not use. Do not reproduce its YAML, TOML or
   Markdown generation in the conversation.
2. Run the same selection with `--check`. It must report that every adapter and
   command is current:

   ```bash
   scripts/sdd-onboard.sh --check claude cursor copilot gemini codex
   ```

3. Confirm the generated paths are ignored with `git check-ignore`. The shipped
   `.gitignore` covers `CLAUDE.md`, `GEMINI.md`, `.claude/`, `.cursor/`,
   `.gemini/`, `.codex/`, `.github/copilot-instructions.md`, `.github/prompts/`,
   `.github/chatmodes/`, `.github/skills/`, `.github/instructions/` and
   `.github/hooks/`.
4. If the generator refuses an existing file, stop. It only updates files with
   its management marker; merge a hand-written customization deliberately
   instead of overwriting it.
5. Report the generated paths per tool. A team that wants to share an adapter
   may remove its ignore rule and commit it; the generator remains its source.

## What the generator guarantees

- The `Rule 1` block is copied byte-for-byte from `AGENTS.md` into each adapter.
- One command wrapper is derived from every file under `docs/commands/`.
- **Each command wrapper suggests a model and asks, and nothing sets one.** The
  tier is declared by the workflow itself, on a `Reasoning:` line — `high`,
  `standard` or `mechanical` — with the rationale after it; a command that does
  not say is `standard`. Tiers rather than model names, so the day a model is
  superseded there is one place to change it and not one per command per
  repository:

  | Tier | Where it goes | `claude` | `copilot` | `codex` |
  | --- | --- | --- | --- | --- |
  | `high` | The commands that decide what the product must do: `specify`, `clarify`, `adopt` | `opus` | `Claude Opus 5` | `gpt-5.5` |
  | `standard` | The commands that fill in what was decided: `init` | `sonnet` | `Claude Sonnet 5` | `gpt-5.4` |
  | `mechanical` | The commands that read a header or run a script: `status`, `onboard` | `haiku` | `Claude Haiku 4.5` | `gpt-5.4-mini` |

  **Nothing generated pins a model.** Every adapter, in every tool, opens by
  telling the user the tier, the suggested model and the model it is actually
  running on — then stops and waits. They confirm or switch, and the command
  continues on whatever they chose. It never refuses a model and never changes
  one itself.

  That is deliberate. Choosing someone's model for them is a cost and a quality
  decision taken out of their hands, and it breaks silently on an account that
  does not have that model. Asking costs one turn and makes the trade-off
  visible at the moment it is being made.

  **The suggestion is per tool, because the catalogues do not match.** Claude
  Code names models one way, Copilot another, Codex another again. Claude's are
  the unversioned aliases deliberately — they follow the vendor's current release
  and never go stale — while the others name versions and are the ones to review
  when a model is superseded.

  **`.sdd/models.yml` is where this is configured.** It is committed, so the
  whole team gets the same suggestions; edit it and re-run `/sdd-onboard`. A
  tool or tier it does not name falls back to the defaults above, so a partial
  table is fine, and a tool with no table at all reports the tier and suggests
  nothing:

  ```yaml
  claude:
    high: opus
  copilot:
    high: GPT-5.5          # an account with no Claude models
  ```

  For a one-off, without editing the table, export a variable and run the
  generator from a terminal — the slash command runs in a chat and takes no
  environment:

  ```bash
  SDD_MODEL_COPILOT_STANDARD='GPT-5.4' bash scripts/sdd-onboard.sh copilot
  SDD_MODEL_HIGH='…' bash scripts/sdd-onboard.sh claude copilot codex
  ```

  Most specific wins: `SDD_MODEL_<TOOL>_<TIER>`, then `SDD_MODEL_<TIER>`, then
  `.sdd/models.yml`, then the defaults.
- One subagent or chat mode is derived from every file under `docs/agents/`, for
  the tools that have one (`claude`, `copilot`). `cursor` and `gemini` have no
  native subagent concept and are skipped rather than approximated.
- One skill directory is copied as-is from every `docs/skills/<slug>/SKILL.md`,
  for the tools with a native skill directory (`claude`, `copilot`).
- One scoped rule is derived from every file under `docs/standards/`, for the
  tools with per-file scoping (`copilot`'s `applyTo`, `cursor`'s `globs`).
  `claude` and `gemini` have no such mechanism; a standard that must always
  apply belongs in `AGENTS.md` instead.
- **One PreToolUse hook per tool, registering `scripts/sdd-hook.sh`.** It
  rewrites a handful of read-heavy commands to run through
  `scripts/sdd-compact.sh`, so their output reaches the model already condensed.
  The hook never blocks, never approves, and rewrites nothing it cannot parse —
  see `docs/token-budget.md` for the allowlist and the refusal rules.
- Re-running with the same inputs produces the same bytes.
- `--check` writes nothing and reports missing or stale generated files.
- A file without the management marker is never overwritten.

The supported adapters are `CLAUDE.md`, `GEMINI.md`,
`.github/copilot-instructions.md` and `.cursor/rules/00-spec-first.mdc`. Command
wrappers are generated under each tool's native command directory. Tools that
read `AGENTS.md` natively can follow `docs/commands/<name>.md` directly.

| Category | Source | claude | copilot | cursor | gemini | codex |
| --- | --- | --- | --- | --- | --- | --- |
| Command | `docs/commands/*.md` | `.claude/commands/` | `.github/prompts/` | `.cursor/commands/` | `.gemini/commands/` | `.codex/prompts/` |
| Agent | `docs/agents/*.md` | `.claude/agents/` | `.github/chatmodes/` | — | — | — |
| Skill | `docs/skills/<slug>/SKILL.md` | `.claude/skills/` | `.github/skills/` | — | — | — |
| Standard | `docs/standards/*.md` | — | `.github/instructions/` | `.cursor/rules/` | — | — |
| Hook | `scripts/sdd-hook.sh` | `.claude/settings.local.json` | `.github/hooks/` | `.cursor/hooks.json` | `.gemini/settings.json` | `.codex/hooks.json` |

`codex` gets no instructions adapter: Codex reads the repository's `AGENTS.md`
itself, and a second file saying the same thing is one more file to keep in step.

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
