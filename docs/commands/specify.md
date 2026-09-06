# /sdd-specify — write a new spec

**Goal.** Turn a product request into `specs/<NNN-slug>/spec.md`: WHAT and WHY,
testable and approvable. No technical decisions and no repository boundaries —
both belong to the `plan.md` of each repository that implements it.

Argument: a description of the feature. If it is missing, ask for it.

## Read first

- `AGENTS.md` — scope, boundaries, and what "done" means here.
- `docs/constitution.md` — constraints an individual spec cannot override.
- `specs/` and `specs/INDEX.md` — the next free number, and whether an existing
  spec already covers part of this. Overlapping scope is a question, not a silent
  merge, and a spec that replaces another supersedes it rather than duplicating
  it.
- `docs/templates/spec.md` — the structure to produce.
- `docs/templates/wireframe.html` — only if `AGENTS.md` says this product has a
  user interface and this feature puts something on a screen.
- `docs/product/` — the glossary and whatever product documentation exists. Use
  the words the product already uses; do not invent a second name for a thing
  that has one.
- `docs/consumers.md` — what the repositories consuming this spec are entitled
  to, and `docs/lifecycle.md` for the statuses.
- Enough of the product's existing specs to describe the problem accurately.
  There is no codebase here, and that is deliberate: a question about how
  something is currently built is a question for the repository that built it.

## Ask only

What changes the WHAT: who the users are and what they are trying to do, what is
explicitly out, how someone would know it works, which constraints are real
today. Ambiguity you can resolve by reading, resolve by reading.

Do not ask how it should be built. If the answer would only change `plan.md`,
it is not a question for this stage.

Anything still open when the spec is written goes to `## Open questions` instead
of being guessed. That is what the section is for, and `/sdd-clarify` closes it.

## Steps

1. Read, then restate the request in two or three sentences and name what you
   understood to be out of scope. A wrong reading surfaces here, cheaply.
2. Ask what is missing.
3. Take the next free `NNN` in `specs/` — zero-padded, never reused, never
   renumbered — and a short slug. The number is the permanent id for commits,
   branches, issues, and for every consumer's `spec.link.yml`. The slug travels
   with the spec into every repository that implements it, so choose it for how
   it will read there.
4. Write `spec.md` from the template. Requirements are numbered `R1`, `R2`, …;
   every acceptance criterion names the requirement it verifies and is phrased so
   its result is observable. If you cannot say how a requirement would be
   verified, it is not a requirement yet — rewrite it. Write them as product
   behaviour: an endpoint, a framework, a table or a repository name in a
   requirement is a HOW decision that leaked into the spec. Fill the metadata
   header — owner, dates, and the repositories expected to implement it, or
   `unknown` when nobody has decided yet.
5. Wireframe — only when `AGENTS.md` says this product has a user interface *and*
   this feature puts something on a screen. Copy `docs/templates/wireframe.html`
   into the spec directory and draw it: one section per screen in scope and no
   screen the spec does not name, each at the project's breakpoints, with the
   states the spec calls for, and the banner filled with this spec's path. Draw
   arrangement, hierarchy and on-screen content — never color, type, iconography
   or components: a wireframe that looks finished gets reviewed as a design
   instead of a layout. Every element traces to a requirement, so if you find
   yourself drawing something no requirement asks for, the spec is incomplete.
   Fix the spec; do not invent it here.
6. One spec per product story, whole, however many repositories it takes. Do not
   split the work between repositories and do not write a contract — both are
   decided in the consuming repositories' plans. `## Consumers` names who is
   expected to implement it; it documents, it does not assign.
7. Update `specs/INDEX.md`: one row for the new spec, its status and its
   consumers.
8. Report the requirements and anything left open.

## Writes

`specs/<NNN-slug>/spec.md`, plus `wireframe.html` beside it when step 5 applies,
and the row in `specs/INDEX.md`. Nothing else — no `plan.md`, no `tasks.md`, no
code, not here and not in any other repository.

## Stops when

`spec.md` is written, and its wireframe if the feature has screens. Approval
belongs to the user: `## Open questions` must be empty, and `/sdd-status <NNN>
approved` records it. Next: `/sdd-clarify` if anything is open. Once approved,
the work leaves this repository — each consuming repository syncs the spec and
runs `/sdd-plan` there.
