# /sdd-init — prepare the Spec Repository

**Goal.** Leave this repository ready to run `/sdd-specify` → `/sdd-clarify` →
`/sdd-status`: `AGENTS.md`, `docs/constitution.md` and `README.md` filled with
what is true about *this* product, and nothing else invented. Runs once per repo.

Agent tooling is not this command's job — that is `/sdd-onboard`, run once per
developer. This one touches no adapter or command files.

Argument: `new` (a product with no specs written yet) or `existing` (there are
specs, product documents or a previous spec system to fold in). If it is missing,
decide by looking.

## Read first

Always: `AGENTS.md`, `docs/constitution.md`, `README.md`,
`docs/templates/readme.md`, `docs/consumers.md`, `docs/lifecycle.md`.

`existing` only, before asking anything:

- The README the repository had **before** the template was copied in —
  `git show HEAD:README.md`, or the revision `git log --oneline -- README.md`
  points at.
- Whatever specs, product documents, glossaries or decision records are already
  here, and how they are numbered and named.
- **A previous spec system**, if there is one: `.specify/`, `.kiro/specs/`,
  `memory/constitution.md`, an `rfcs/` or `adr/` directory, a `docs/features/`
  full of feature documents. Its rules and constitution are an input to this
  command; its specs are not — those are `/sdd-adopt`, one at a time.
- The repositories that will consume these specs, if any exist yet. Their names
  and what each builds is what `docs/consumers.md` and every spec header need.

## Ask only

What the repository cannot tell you. Ground every convention in a file you read,
and name that file when you report it.

- What the product is and who it is for. This repository holds no code, so this
  is a question, not something to derive.
- Which repositories implement these specs, and what each of them builds. "None
  yet" is an answer.
- The product constraints for the constitution: compliance, data residency,
  accessibility level, markets and languages, commitments no spec may
  contradict. Product-level only — a stack or a performance budget belongs to a
  development repository. If there are none, say so.
- Whether the product has a user interface, and at which breakpoints. It decides
  whether a spec gets a wireframe.
- Who approves a spec, and how consumers read this repository: a branch they
  track, or a tag they pin. It decides what `docs/lifecycle.md` and
  `docs/consumers.md` have to say, and whether `.github/workflows/` stays.

## Steps

1. Read. For `existing`, report what you found *before* asking anything — the
   user corrects your reading more cheaply than your questions.
2. Ask, in one round where possible.
3. Fill `AGENTS.md`: Product, Conventions, Boundaries, Done means. Delete every
   `<...>` you cannot fill; an unfilled placeholder is paid for on every turn.
   Never touch the Rule 1 block, its `<!-- sdd:rule1:* -->` delimiters, or the
   "Read on demand" table. Keep the file at 60 lines or fewer. The `Interface`
   line is the one placeholder to fill rather than delete when it does not apply:
   `/sdd-specify` reads it, and `none` is an answer.
4. Fill `## Project constraints` in `docs/constitution.md`, or delete that
   section. Leave the six principles and the Amendments section alone — changing
   a principle needs the user's explicit approval and an Amendments entry.
5. Rewrite `README.md` from `docs/templates/readme.md`. The one that ships with
   the template documents *the template*. Aim it at a person arriving at the
   repository: what the product is, where the specs are, how to read one, and how
   a development repository consumes them. Delete every `<...>` you cannot ground.
   For `existing`, carry over what the project's own README already said and add
   only the sections it lacked.
6. Name the consumers in `docs/consumers.md` → `## Naming the consumers`: one
   line per repository and what it builds. None yet: say so there, rather than
   inventing a topology.
7. Adapt `docs/lifecycle.md` where the answers contradict it: who approves, and
   whether consumers track a branch or pin a tag. It ships with a default, not
   with a fact about this product. Not on GitHub Actions: delete
   the template workflows only after naming the CI configuration that runs
   `scripts/sdd-check.sh`; keep that script as the portable entry point. A
   workflow for a CI nobody uses is worse than no workflow, but deleting it is
   not a CI integration. Never invent a process nobody follows; "not decided
   yet" is an answer. Point `.github/CODEOWNERS` at a
   reviewer who actually has access, or delete it — a file naming someone
   without access asks for a review GitHub will silently never request.
8. Delete any spec directory that is not this product's — `specs/INDEX.md`
   already ships empty of rows. Delete `docs/templates/readme.md` too — it is
   spent, the README is written — and `docs/templates/index.md` once
   `specs/INDEX.md` starts holding real rows. With no user interface, delete
   `docs/templates/wireframe.html` as well. Delete `CHANGELOG.md` if it carries
   the template's own releases: a repository created from a template inherits it,
   and a changelog opening with someone else's versions is lying from its first
   line.
9. Seed `docs/product/glossary.md` only with terms the user actually used, or
   delete it. A glossary of invented words is worse than none.
10. If you found a previous spec system, list its specs and stop there. Do not
    convert them — say how many there are and that `/sdd-adopt <path>` takes them
    one at a time.

## Writes

`AGENTS.md`, `docs/constitution.md`, `README.md`, `docs/consumers.md`,
`docs/lifecycle.md` and `.github/CODEOWNERS`. It deletes the inherited
`CHANGELOG.md` and the spent templates, and `.github/workflows/` when the
repository is not on GitHub Actions. No specs, no plans, no tasks, no code, and
no conversion of anyone else's specs.

## Stops when

`AGENTS.md`, `docs/constitution.md` and `README.md` are written. Report what you
grounded in which file, what came from the user's answers, and which repositories
were recorded as consumers. Next: `/sdd-specify`, or `/sdd-adopt` if there are
specs worth carrying over.
