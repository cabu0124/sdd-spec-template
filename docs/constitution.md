# Constitution

Durable principles for this product's specifications. They outrank convenience,
habit and any individual spec. Read this when a spec is silent and you must
choose.

This is not a style guide — style lives in `AGENTS.md`.

## Principles

1. **Spec First, and WHAT only.**
   No code anywhere without an approved spec here — for anything that changes
   WHAT the product does. And nothing in a spec that decides HOW: no technology,
   no repository, no schema, no rollout. Trivial changes (a typo, the SDD
   scaffolding itself) skip the process; for the middle ground — a reworded
   requirement, a small scope change — ask rather than assuming either way.
   *Why:* intent written down before code is reviewable, testable and cheap to
   change. Intent discovered from code is none of those. And a spec that decides
   HOW takes the decision away from the only people who can see the codebase it
   would be taken in.

2. **Simplicity over cleverness.**
   Specify the problem the product has, not the one it might have later. A
   requirement nobody needs yet is built, tested and maintained by somebody.
   *Why:* scope written down is scope somebody will implement.

3. **Every requirement is testable.**
   If you cannot state how to verify it, it is not a requirement yet — rewrite it.
   Verifiable from the outside: an acceptance criterion that needs to know how it
   was built is a HOW that leaked in.
   *Why:* "done" must be observable, not a matter of opinion — and observable by
   every repository that took a share of the spec.

4. **One spec, one product story.**
   A spec covers one thing a user can do, whole, whatever number of repositories
   it takes to build. Split by story, never by repository or by team.
   *Why:* a spec split by repository stops describing the product, and nobody can
   answer whether the story works.

5. **An approved spec is published.**
   Consumers have copied it and may have built against it. Change it in the open:
   an amendment line, and a word about who must re-sync. Replace, rather than
   rewrite, when the decision itself has changed.
   *Why:* several repositories share one document. Silent edits give each of them
   a different version of what was agreed.

6. **Explicit over implicit.**
   State assumptions in the spec. When blocked, ask — never guess and proceed.
   Undecided goes in `## Open questions`, which is why a spec cannot be approved
   while any remain.
   *Why:* a wrong silent assumption is discovered late, after code depends on it.

## Project constraints

<Non-negotiables specific to this product: regulatory and compliance rules, data
residency, accessibility level, supported markets or languages, commitments no
individual spec may contradict. Product-level only — a platform or a performance
budget that belongs to one implementation belongs in that repository. Delete this
section if there are none — an empty placeholder is worse than nothing.>

## Amendments

Changing this file requires explicit human approval. Append the date and the
reason below; never edit a principle silently. Every repository that implements
these specs inherits it, so an amendment here is announced to all of them.

- `YYYY-MM-DD` — Initial version.
