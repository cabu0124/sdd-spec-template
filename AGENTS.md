# AGENTS.md — [product] specs

<!-- Fill <...>. Delete what doesn't apply. Keep under 60 lines: this loads every session. -->

**Source of truth for every agent.** Tool adapters (`CLAUDE.md`, `GEMINI.md`, …) are generated
per developer by `docs/commands/onboard.md`, only point here, and hold no project content.

<!-- sdd:rule1:start -->
## Rule 1 — Specs Only, Spec First

This repository holds specifications and product documentation. **No plans, no task
lists, no source code** — those belong to the repositories that implement a spec, because
they depend on a codebase this one does not have. Asked for any of them: say where it
belongs and stop.

Classify the request before writing:

- **No spec — just do it:** typo/wording fix, formatting, a change to the SDD scaffolding itself (`AGENTS.md`, `docs/`, templates, agent command/skill files), or product documentation that decides nothing.
- **Ask first — never assume:** a wording change that could alter how a requirement is read, a scope tweak, or anything you are unsure about. Ask *"spec this, or handle it as a no-spec change?"* and follow the answer.
- **Spec required:** anything that changes WHAT the product does — user-visible behaviour, a rule, a data meaning. Then:

1. Find the spec in `specs/` — one directory per spec, `NNN-slug`, never renumbered. New: write it from `docs/templates/spec.md` with `/sdd-specify` and STOP for approval.
2. Keep it technology-agnostic. An endpoint, a framework, a table, a repository name or a rollout decision in a requirement is HOW, and HOW is not ours.
3. An approved spec is a published contract: consumers have mirrored it. Change it through `/sdd-clarify` or a new version, move its status with `/sdd-status`, and say who has to re-sync.
<!-- sdd:rule1:end -->

## Product

<What the product is and who it is for, 2-3 lines.>
<Interface: web · mobile · desktop · none, and its breakpoints. Drives wireframes.>

## Conventions

- Spec ids: `NNN-slug`, zero-padded, never reused, never renumbered
- Statuses: `draft` → `review` → `approved` → `done`, plus `superseded` — see `docs/lifecycle.md`
- <Domain language: the glossary is `docs/product/glossary.md`>

## Boundaries

- Never write here: `plan.md`, `tasks.md`, source code, contracts, schemas
- Never edit: an `approved` spec's requirements without `/sdd-clarify` and an amendment line
- Ask before: changing a spec consumers have already implemented

## Done means

- [ ] Every requirement is testable, and free of technology
- [ ] Every acceptance criterion names the requirement it verifies
- [ ] `## Open questions` is empty before `status: approved`, and
      `specs/INDEX.md` is regenerated with `scripts/spec-index.sh`

## Read on demand (not upfront)

| Need | File |
| --- | --- |
| Running a stage of the loop | `docs/commands/` |
| Principles, trade-off rules | `docs/constitution.md` |
| Statuses, versions, amendments | `docs/lifecycle.md` |
| What development repos expect, who consumes what | `docs/consumers.md` |
| Active spec | `specs/<NNN-slug>/` |
| Artifact structure | `docs/templates/` (incl. `wireframe.html`) |
| Product language, glossary | `docs/product/` |
