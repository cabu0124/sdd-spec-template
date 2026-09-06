# /sdd-onboard — set up your agent tool for this repo

**Goal.** Scaffold the files *your* agent tool needs — an adapter that points at
`AGENTS.md` plus command files for the loop — and keep them out of version
control. The template ships none of them: `AGENTS.md` and `docs/` are the whole
method, and each developer runs this once for the tool they use.

Runs per developer, not per repo. Re-run it any time to add another tool, or
after the `Rule 1` block in `AGENTS.md` changes.

Argument: a tool name (`claude`, `cursor`, `copilot`, `gemini`), or empty to be
asked.

## First run, before any command files exist

On a fresh clone `/sdd-onboard` does not exist yet — nothing tool-specific is
committed. Point your agent at this file directly:

> Follow `docs/commands/onboard.md`.

It generates the command files, so from then on `/sdd-onboard`, `/sdd-init` and
the rest work as slash commands.

## Read first

- `AGENTS.md` — the `Rule 1 — Spec First` block between `<!-- ssd:rule1:start -->`
  and `<!-- ssd:rule1:end -->` is copied verbatim into every adapter.
- `.gitignore` — it already lists the generated paths; you only add to it if a
  tool needs a path not there yet.
- Whatever agent files already exist, so a re-run updates instead of duplicating.

## Ask only

Which tools do you use? One round, multi-select:

Claude Code · Cursor · GitHub Copilot · Gemini CLI / Antigravity · something
else · none.

Nothing else — everything below is mechanical once the tools are known.

## Which tools need what

`AGENTS.md` is the cross-tool standard and most agents read it natively. Four
need an adapter, each for a specific reason:

| Tool | Adapter file | Why |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | Does not read `AGENTS.md`; the `@AGENTS.md` import pulls it in |
| Antigravity | `GEMINI.md` | Reads `AGENTS.md`, but `GEMINI.md` applies first and wins |
| Gemini CLI | `GEMINI.md` | Native `GEMINI.md`; same adapter |
| GitHub Copilot | `.github/copilot-instructions.md` | `AGENTS.md` support in chat is inconsistent; Copilot CLI ignores it |
| Cursor | `.cursor/rules/00-spec-first.mdc` | Reads `AGENTS.md` only as a fallback; `alwaysApply: true` outweighs it |

These read `AGENTS.md` natively and need no adapter: Codex, VS Code, Windsurf,
Zed, Junie (JetBrains), Aider, Devin, Warp, Amp, goose, RooCode, Kilo Code,
Factory, opencode, Jules, Augment Code, Ona, Semgrep.

## Steps

1. **Adapter** — for each selected tool in the table, write its adapter file with
   exactly two things:
   - a pointer: *read `AGENTS.md` at the repository root and follow it*, and a
     line saying not to put project content in this file;
   - the `Rule 1` block from `AGENTS.md`, copied **verbatim**, delimiters
     included.

   Claude Code's also carries the `@AGENTS.md` import line. Cursor's needs the
   frontmatter `alwaysApply: true`. Antigravity has no command system, so its
   adapter is all it needs.

2. **Command files** — for each selected tool that has a command system, generate
   one `sdd-<name>` file per workflow in `docs/commands/` (`onboard`, `init`,
   `adopt`, `specify`, `clarify`, `status`). Each
   file is a pointer, no content of its own:

   ```markdown
   Read `docs/commands/<name>.md` and follow it.

   Input: <arg>
   ```

   | Tool | Location | `<arg>` | Format |
   | --- | --- | --- | --- |
   | Claude Code | `.claude/commands/sdd-<name>.md` | `$ARGUMENTS` | markdown, YAML frontmatter |
   | Cursor | `.cursor/commands/sdd-<name>.md` | `$ARGUMENTS` | markdown |
   | Copilot | `.github/prompts/sdd-<name>.prompt.md` | `${input:args}` | markdown |
   | Gemini CLI | `.gemini/commands/sdd-<name>.toml` | `{{args}}` | TOML |

   Claude Code and Gemini CLI show a `description`; Claude Code also takes an
   `argument-hint`. Derive both from the workflow file: the description is the
   phrase after the em dash in its `# /sdd-<name> — …` heading, the hint is its
   `Argument:` line. Claude Code frontmatter:

   ```markdown
   ---
   description: write a new spec from a feature description
   argument-hint: <what the feature is and who needs it>
   ---

   Read `docs/commands/specify.md` and follow it.

   Input: $ARGUMENTS
   ```

   The plain markdown tools (Cursor, Copilot) need only the two-line body, which
   generates in one pass:

   ```bash
   dir=.cursor/commands ext=md arg='$ARGUMENTS'
   # Copilot: dir=.github/prompts  ext=prompt.md  arg='${input:args}'
   mkdir -p "$dir"
   for f in docs/commands/*.md; do
     n=$(basename "$f" .md)
     printf 'Read `docs/commands/%s.md` and follow it.\n\nInput: %s\n' \
       "$n" "$arg" > "$dir/sdd-$n.$ext"
   done
   ```

   For Claude Code, do the same into `.claude/commands/sdd-<name>.md` but prepend
   the frontmatter block above, filled per command.

   Gemini CLI takes one TOML file per command instead:

   ```toml
   description = "Write a new spec from a feature description"
   prompt = "Read docs/commands/specify.md and follow it.\n\nInput: {{args}}"
   ```

3. **`.gitignore`** — confirm every path just written is ignored. The shipped
   `.gitignore` covers `/CLAUDE.md`, `/GEMINI.md`, `/.claude/`, `/.cursor/`,
   `/.gemini/`, `/.github/copilot-instructions.md` and `/.github/prompts/`. Add a
   line only if a tool put a file somewhere not listed. Check with
   `git check-ignore <path>`.

4. **Native tools** — for a tool that reads `AGENTS.md` and has no command
   system, there is nothing to generate. `docs/commands/<name>.md` is readable
   prose: *"Follow `docs/commands/specify.md`. Input: …"* does the same job.

5. **Report** what you created, per tool. Mention the escape hatch: a team that
   wants an adapter shared removes its line from `.gitignore` and commits it.

## Keeping Rule 1 in sync

Every adapter repeats the `Rule 1` block, so it must stay byte-identical to
`AGENTS.md`. After editing that block, re-run `/sdd-onboard` for each tool, or
check the hashes directly (only over files that exist):

```bash
for f in AGENTS.md CLAUDE.md GEMINI.md \
         .github/copilot-instructions.md .cursor/rules/00-spec-first.mdc; do
  [ -f "$f" ] || continue
  printf '%s  %s\n' \
    "$(sed -n '/ssd:rule1:start/,/ssd:rule1:end/p' "$f" | shasum | cut -c1-8)" "$f"
done
```

All hashes must match.

## Does it actually work?

Adding the files is not the test. Two checks:

- Ask for something that is not this repository's to write — *"write the plan for
  spec 3"*, or *"implement it"*. It passes if it says plans, tasks and code
  belong to the repository that builds the spec, and stops.
- Ask for a spec that decides HOW — *"spec a REST endpoint for password
  reset"*. It passes if it writes requirements about what a user can do and
  leaves the endpoint out; it fails if the endpoint reaches a requirement.

## Writes

Adapter files, `sdd-<name>` command files, and `.gitignore` — all for the tools
you selected. No project content: that is `/sdd-init`. No spec, no code.

## Stops when

Each selected tool has its adapter and command files, every generated path is
gitignored, and the refusal test passes. Next: `/sdd-init new|existing`.
