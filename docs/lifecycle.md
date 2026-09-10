# Lifecycle — statuses, versions, amendments

A spec is a document with a life: it is drafted, questioned, approved, built by
one or more repositories, and eventually replaced. This repository owns that
lifecycle. `status:` in the spec header is the record, and everything downstream
reads it.

## Statuses

| Status | Means | Who moves it | Consumers may |
| --- | --- | --- | --- |
| `draft` | Being written. Requirements may still change wholesale | the author | read it, plan nothing |
| `review` | Complete and awaiting sign-off. `## Open questions` must be empty | the author | read it, plan nothing |
| `approved` | Signed off. The published contract | **the user only** | sync it, plan, build |
| `done` | Every consuming repository has met the criteria it took | the user | nothing changes |
| `superseded` | Replaced by another spec, which is named in the header | the user | stop, and read the successor |

Two rules give the statuses their meaning:

- **`approved` is the only status a development repository may build against.**
  `/sdd-plan` in a consuming repo refuses anything else. That refusal is the
  whole point of the gate.
- **Only the user approves.** An agent writes, clarifies and reports — it never
  sets `approved`. `## Open questions` must be empty first.

```text
draft ──▶ review ──▶ approved ──▶ done
                          │
                          └──▶ superseded ──▶ (successor spec)
```

Backwards is allowed and is not a failure: `approved → draft` when something is
found to be wrong. It is a **published** change, so it is announced — see below.

## Changing an approved spec

Consumers have mirrored it and may have built against it. Three cases:

| The change | What to do |
| --- | --- |
| Wording, typo, a clarification that cannot change what is built | Edit in place, add an amendment line, keep `approved` |
| A requirement or an acceptance criterion changes | `/sdd-clarify`, add an amendment line, and say which consumers must re-sync and re-plan |
| The product decision itself changed | A **new spec** that supersedes this one. Do not rewrite history a consumer has already implemented |

Every spec carries `## Amendments`, append-only:

```markdown
- `2026-03-14` — R3 reworded: "within a day" → "within 15 minutes". Consumers: re-sync.
```

That line is what a consuming repository reads to know its plan may no longer
hold. It costs one line and it is the only mechanism keeping several
repositories honest about the same document.

## Numbers, slugs and versions

- `NNN-slug`, zero-padded, **never reused and never renumbered.** The number is
  the permanent id in commits, branches, issues and every consumer's
  `spec.link.yml`.
- The slug travels with the spec into every repository that implements it. Their
  local numbers differ; the slug does not.
- There are no per-spec version numbers. Git holds the history, the amendments
  hold the summary, and consumers pin to a commit or a tag — see
  `docs/consumers.md`.

## Versioning

Merges to `main` are tagged and released by `.github/workflows/release.yml`,
from the pull request titles. Nobody types a version number — the bump comes
from the type on the title:

| Pull request title | Bump |
| --- | --- |
| `<type>!:` or a `BREAKING CHANGE:` footer | major |
| `feat(NNN): …` | minor |
| `fix(NNN): …` or `perf(NNN): …` | patch |

Those tags are what a consuming repository pins to when it wants a reviewed set
of specs rather than the moving branch:

```yaml
# in the consumer's .sdd/config.yml
ref: v1.4.0   # instead of: main
```

Pull request titles follow Conventional Commits, with the spec number as the
scope — `feat(014): password reset spec`, `fix(014): clarify R3`.

Branches are the same two as everywhere else: `feature/*` and `fix/*` into
`develop`, `develop` into `main`. There are no feature flags here — a spec is not
deployed, it is approved.

## The index

`specs/INDEX.md` lists every spec with its status and its consumers. It is
generated from the spec headers by `scripts/spec-index.sh` — every command that
used to edit it by hand now calls that script instead — so it cannot disagree
with the specs it lists: the header is the only place a status, an owner or a
consumer is ever typed.

The `specs-index` job in `.github/workflows/specs-index.yml` enforces that on
every pull request: `scripts/spec-index.sh --check` fails the build if
`specs/INDEX.md` is not what the headers would generate, `scripts/spec-check.sh`
fails it if an `approved` spec still has an unchecked open question, an id is
not `NNN-slug` zero-padded, a placeholder is still committed, or a `superseded`
spec names no successor — and the Rule 1 check still refuses a `plan.md` or a
`tasks.md` anywhere in the repository. Consumers read this branch while they
build, so it cannot hold a catalogue that lies about what is approved.
