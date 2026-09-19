# /sdd-specify — write a new spec

**Goal.** Turn a product request into `specs/<id>-<slug>/spec.md`: WHAT and WHY,
testable and approvable. No technical decisions and no repository boundaries —
both belong to the `plan.md` of each repository that implements it.

Argument: `[<id>] <description>` — the id this spec will carry, and what the
feature is. The id is optional only where `.sdd/config.yml` says
`spec_id.source: sequential`; see step 3. If the description is missing, ask for it.

Reasoning: high — it writes WHAT the product must do, and a requirement that can be read two ways is read two ways by every repository that implements it.

## Read first

- `AGENTS.md` — scope, boundaries, and what "done" means here.
- `docs/constitution.md` — constraints an individual spec cannot override.
- `specs/` and `specs/INDEX.md` — whether this id already has a spec, and whether
  an existing spec already covers part of this. Overlapping scope is a question,
  not a silent merge, and a spec that replaces another supersedes it rather than
  duplicating it.
- `.sdd/config.yml` — the shape of a spec id here, and where a new one comes from.
- `docs/templates/spec.md` — the structure to produce.
- `docs/skills/drawing-wireframes/` — only if `AGENTS.md` says this product has a
  user interface and this feature puts something on a screen. The template it
  points to is read by the subagent that draws, not here.
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

1. Survey, then read, then restate. Hand the reconnaissance to the
  `spec-explorer` subagent — whether this id already has a spec, which specs
  overlap and in which requirement, two requirements quoted verbatim as a model
  for voice, and the glossary terms that apply — and **do not read the specs its
  report summarises**. Read `AGENTS.md`, `docs/constitution.md` and
  `docs/templates/spec.md` yourself: you will be writing against them. Then
  restate the request in two or three sentences and name what you understood to
  be out of scope. A wrong reading surfaces here, cheaply.
2. Ask what is missing.
3. Settle the id before writing anything. `.sdd/config.yml` says where it comes
  from:
   - **Given as an argument** — use it exactly as written. Never re-cased,
     re-padded or renumbered: it is the id the backlog uses, and the one every
     consumer's `spec.link.yml` will record.
   - **Absent, `source: sequential`** — suggest the next free one in `specs/` and
     **ask before continuing**.
   - **Absent, `source: given`** — ask for it and stop. An id minted here is an id
     the backlog does not use, and the same work ends up with two.

  Then add a short slug: `<id>-<slug>`. The id is permanent — commits, branches,
  issues, and every consumer's `spec.link.yml` — and the slug travels with the
  spec into every repository that implements it, so choose it for how it will read
  there. If a spec for that id already exists, stop and say so: one story, one
  spec — amend it with `/sdd-clarify` or supersede it, never mint a second.
4. Write `spec.md` from the template. Requirements are numbered `R1`, `R2`, …;
   every acceptance criterion names the requirement it verifies and is phrased so
   its result is observable. If you cannot say how a requirement would be
   verified, it is not a requirement yet — rewrite it. Write them as product
   behaviour: an endpoint, a framework, a table or a repository name in a
   requirement is a HOW decision that leaked into the spec. Fill the metadata
   header — owner, dates, and the repositories expected to implement it, or
   `unknown` when nobody has decided yet.
5. Wireframe — only when `AGENTS.md` says this product has a user interface *and*
   this feature puts something on a screen. Follow
   `docs/skills/drawing-wireframes/`, which carries this product's notation and
   the rules a wireframe here must follow. Hand the first drawing to the
   `wireframe-artist` subagent: it writes `specs/<id>-<slug>/wireframe.html`
   itself and reports rather than returning the markup — the template is large,
   and handing it back would undo the point of delegating. Iterate here
   afterwards, reading the drawn file rather than the template again.
6. One spec per product story, whole, however many repositories it takes. Do not
   split the work between repositories and do not write a contract — both are
   decided in the consuming repositories' plans. `## Consumers` names who is
   expected to implement it; it documents, it does not assign. When it names
   more than one, fill `## Verification` — a row per acceptance criterion and
   the repository that answers for it — and name the `Verifier:` who runs the
   criteria that only hold with several repositories running together. Leave the
   evidence column empty; it is filled as each one passes. A single-repo spec
   deletes the section and the header line.
7. Regenerate `specs/INDEX.md`: `scripts/spec-index.sh`.
8. Report the requirements and anything left open.

## Writes

`specs/<id>-<slug>/spec.md`, plus `wireframe.html` beside it when step 5 applies,
and `specs/INDEX.md`, regenerated by `scripts/spec-index.sh` rather than edited
by hand. Nothing else — no `plan.md`, no `tasks.md`, no
code, not here and not in any other repository.

## Stops when

`spec.md` is written, and its wireframe if the feature has screens. Approval
belongs to the user: `## Open questions` must be empty, and `/sdd-status <id>
approved` records it. Next: `/sdd-clarify` if anything is open. Once approved,
the work leaves this repository — each consuming repository syncs the spec and
runs `/sdd-plan` there.
