# Consumers — the contract with development repositories

This repository is read by others. Frontend, backend, workers, infrastructure:
each mirrors the specs it implements and writes its own `plan.md` and `tasks.md`
against them. That split is the whole architecture, and this file is the seam.

```text
this repository                     a development repository
  specs/014-password-reset/
    spec.md          ──────────▶      docs/specs/007-password-reset/
    wireframe.html   ──────────▶        spec.md         mirror, byte-identical
                                        wireframe.html  mirror
                                        spec.link.yml   id · ref · commit · sha256
                                        plan.md    ◀── theirs, /sdd-plan
                                        tasks.md   ◀── theirs, /sdd-tasks
```

## What we owe them

**A stable layout.** One directory per spec at `specs/<NNN-slug>/`, holding
`spec.md` and, when the feature has screens, `wireframe.html`. A consumer's
`.sdd/config.yml` names that directory; moving or renaming it breaks every
repository at once.

**A greppable status.** `- **Status:** approved` on its own line in the spec
header. `/sdd-plan` in a consuming repo refuses anything that is not `approved`,
so the line is machine-read as much as it is human-read.

**Nothing but WHAT.** No endpoint, no framework, no schema, no repository name in
a requirement. A consumer that has to strip technology out of a spec to plan
against it is being handed a decision that was not ours to make.

**Whole specs, never narrowed per repo.** One product story is one spec, the same
in every repository. Which repository builds which part is drawn in *their*
`plan.md` → `## Scope in this repo`. Narrow the spec per consumer and the product
has as many WHATs as it has repositories, none of which describes it.

**An amendment line for every change to an approved spec**, naming who must
re-sync. See `docs/lifecycle.md`.

## What they owe us

**Read-only mirrors.** Their copy carries a `sha256` in `spec.link.yml`, checked
by their `/sdd-sync` and `/sdd-analyze`. A spec edited downstream is fixed for one
repository and for nobody else.

**Questions come back here.** Ambiguity, contradiction, something impossible to
build: `/sdd-clarify` in *this* repository, so the answer reaches everyone.

**Their own numbering.** `014-password-reset` here can be `007-password-reset`
there. The slug is the join key; the numbers are local.

## What never enters this repository

| Artifact | Belongs to | Why |
| --- | --- | --- |
| `plan.md` | each development repo | HOW depends on a codebase this repo does not have |
| `tasks.md` | each development repo | the units of work are that repo's |
| API contracts, payloads, schemas, config keys | the owning development repo's `plan.md` | a contract is technology; consumers copy it verbatim between themselves |
| Source code, tests | development repos | — |
| Rollout and feature flags | the development repo's plan | a spec is approved, not deployed |

A contract between two development repositories is settled between them, not
here. Their templates carry `docs/cross-repo.md` for exactly that.

## Naming the consumers

Each spec header lists the repositories expected to implement it:

```markdown
- **Consumers:** `web-app` · `api-svc`
```

It is documentation, not dispatch — no repository is assigned work from here.
What it buys is the ability to answer "who has to re-sync?" when a requirement
changes, which is the question every amendment raises.

`specs/INDEX.md` aggregates the same information across all specs.

## Pinning

A consumer reads a `ref`: a branch tracks specs as they are approved, a tag pins
a reviewed set and makes upgrading deliberate. Both are legitimate; what matters
is that `main` only ever holds specs whose status is honest, because somebody is
building from it right now.
