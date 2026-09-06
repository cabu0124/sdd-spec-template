# /sdd-clarify — close the gaps in a spec

**Goal.** Turn what a spec leaves ambiguous into decisions written into the spec.

Optional before approval, and the only way to change a requirement afterwards.
Run it when the spec has open questions or reads as vague; skip it when it does
not. A clarification round that invents doubts is worse than none.

Questions raised by a consuming repository land here too: that is the point of a
single source of truth, and answering one in the consumer's mirror answers it for
one repository out of several.

Argument: a spec id. If it is missing, take the most recently modified spec whose
status is `draft`.

## Read first

- The spec, and its `wireframe.html` if it has one.
- `docs/constitution.md` and `AGENTS.md` — some ambiguities are already settled
  here, and those you resolve by reading, not by asking.
- `docs/product/` — the glossary settles more wording questions than it looks.
- `docs/lifecycle.md` — what changing an `approved` spec obliges you to do.
- The other specs, where they tell you which readings are even plausible.

## Ask only

One question per real ambiguity, each with the readings you see and what each one
would change. Never ask what the constitution, `AGENTS.md` or the code already
answers. Never ask about implementation — a question that only affects HOW, or which
repository does the work, is answered in that repository's `plan.md`, not here.

What is worth asking about:

- A requirement with two readings that lead to different acceptance criteria.
- An acceptance criterion whose result is not observable.
- A requirement with no acceptance criterion, or a criterion with no requirement.
- Scope that neither `In` nor `Out` settles.
- A contradiction between two requirements, with another spec, or with the
  constitution.
- Anything already listed under `## Open questions`.

## Steps

1. Read the spec against the constitution, `AGENTS.md` and the glossary.
2. List what you found, grouped: ambiguous, contradictory, missing, not testable.
3. If the list is empty, say so and stop.
4. Ask, in one round where possible.
5. Write the answers where they belong: a vague requirement gets rewritten, a
   settled question is struck through with its resolution and date, decided scope
   moves into `In` or `Out`. Do not append a transcript of the conversation, and
   do not let an answer bring technology or a repository name into the spec — an
   answer that only lands in a `plan.md` was never a question for this repository.
   Update the `Updated:` line.
6. If the spec has a wireframe, update it only where an answer changed what is on
   a screen: a field added, a control dropped, an arrangement decided. An answer
   that changes no screen leaves the file byte-identical — resist the urge to
   tidy it while you are in there.
7. **If the spec is `approved`**, it is published: consumers have mirrored it.
   Append an amendment line naming what changed, and report which repositories in
   `## Consumers` must re-sync — and whether the change is large enough that the
   honest move is a new spec superseding this one rather than an edit. See
   `docs/lifecycle.md`.
8. Report what changed, requirement by requirement.

## Writes

The spec — including its `## Amendments` when it was already approved — its
`wireframe.html` when an answer changed a screen, and `specs/INDEX.md` if the
status moved. Never `plan.md`, `tasks.md` or code, here or anywhere else.

## Stops when

Every ambiguity is either resolved in the spec or still listed as an open
question for the user to settle — say which, and name the consumers that need to
re-sync. Approval needs `## Open questions` empty; `/sdd-plan` in a consuming
repository needs `status: approved`.
