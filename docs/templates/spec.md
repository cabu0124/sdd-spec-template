# Spec NNN — [feature name]

<!-- Metadata. Every line is read by a person and some by a machine: keep the
     shapes, fill the values, delete only the lines marked as optional. -->

- **Status:** draft <!-- draft | review | approved | done | superseded — see docs/lifecycle.md -->
- **Created:** YYYY-MM-DD
- **Updated:** YYYY-MM-DD
- **Owner:** <who answers questions about this spec>
- **Consumers:** <repo> · <repo> <!-- repositories expected to implement it; "unknown" is an honest answer -->
- **US:** <id or link> <!-- the story this comes from, if it has one elsewhere; delete if none -->
- **Supersedes:** <NNN-slug> <!-- delete if none -->
- **Superseded by:** <NNN-slug> <!-- delete unless the status is superseded -->

WHAT the product must do, and why. No technology, no repository, no schema, no
rollout: the same spec holds for every repository that implements it. HOW, and
which part each repository builds, belong in *their* `plan.md`.

## Problem

<What is wrong or missing today, and who feels it. 2-4 sentences.>

## Scope

**In:**

- <...>

**Out:**

- <Named exclusions. "Out" is as informative as "In" — it prevents scope drift.
  Product-level only: work another repository does is still *in* scope here. The
  split between repositories is drawn in their `plan.md`, never in this file.>

## Requirements

Numbered and testable. If you cannot say how to verify it, rewrite it. Phrased as
product behaviour — a requirement naming an endpoint, a framework, a table or a
repository is a HOW decision that leaked in.

- **R1** — <...>
- **R2** — <...>

## Acceptance criteria

Each criterion names the requirement it verifies, and is observable from outside
the product.

- [ ] **AC1** (R1) — Given <context>, when <action>, then <observable result>.
- [ ] **AC2** (R2) — <...>

## Non-functional

<Performance, security, accessibility, compatibility budgets — as product
commitments, not as implementation targets. Delete if none.>

## Open questions

What is still undecided. The spec cannot be approved while any remain.

- [ ] <...>

## Amendments

Append-only, and only once the status has been `approved` at least once. Name
what changed and who has to re-sync. See `docs/lifecycle.md`.

- `YYYY-MM-DD` — <what changed, and which consumers it affects>
