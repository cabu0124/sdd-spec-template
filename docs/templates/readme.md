# <product> — specifications

<!-- Fill every <...>. Delete the sections you cannot ground in something real.
     Delete this comment when you are done. -->

> <One line: what the product is and who it is for. The same answer as
> `AGENTS.md` → Product, written for a person who just landed here.>

**This repository holds specifications, not code.** It is the source of truth for
**WHAT** the product does and **why**. How it is built lives in the repositories
that build it.

---

## Reading a spec

Every specification is a directory under [`specs/`](specs/):

```text
specs/
  INDEX.md                every spec, its status and who implements it
  NNN-slug/
    spec.md               problem · scope · requirements · acceptance criteria
    wireframe.html        where things sit on screen — only if it has screens
```

Start at [`specs/INDEX.md`](specs/INDEX.md).

| Status | Means |
| --- | --- |
| `draft` · `review` | Being written or awaiting sign-off. Not to be built |
| `approved` | Signed off. This is what gets built |
| `done` | Every repository has met the criteria it took |
| `superseded` | Replaced — the header names the successor |

Full rules in [`docs/lifecycle.md`](docs/lifecycle.md).

## Who implements these specs

| Repository | Builds |
| --- | --- |
| `<repo>` | <...> |

A development repository mirrors the spec it needs and writes its own `plan.md`
and `tasks.md` against it:

```bash
# in the development repository
/sdd-sync <NNN-slug>     # copies spec.md in, read-only
/sdd-plan <NNN>          # HOW that repository builds it
/sdd-tasks <NNN>
/sdd-implement <NNN>
```

It points at this repository once, in its `.sdd/config.yml`:

```yaml
spec_repo:
  name: <this-repo>
  path: <../this-repo>
  remote: <git remote>
  ref: <main, or a tag to pin>
  specs_dir: specs
```

What consumers may and may not do is in
[`docs/consumers.md`](docs/consumers.md). The short version: **the mirror is
read-only.** A spec that is wrong, ambiguous or impossible is fixed here, where
the fix reaches every repository at once.

## Writing a spec

```text
/sdd-specify → /sdd-clarify → /sdd-status <NNN> approved
    WHAT          the gaps         the gate
```

Specs are technology-agnostic by rule: no endpoint, no framework, no schema, no
repository name in a requirement. Those are decisions for the repository that
can see the codebase they would be taken in.

| Where | What is in it |
| --- | --- |
| `AGENTS.md` | The rules every agent follows |
| `docs/constitution.md` | The durable principles |
| `docs/lifecycle.md` | Statuses, amendments, releases |
| `docs/consumers.md` | The contract with development repositories |
| `docs/commands/` | The workflow behind each command |
| `docs/product/` | Glossary and product documentation |
| `specs/NNN-slug/` | One spec |

> [!TIP]
> **New here?** Set up your agent tool once with `docs/commands/onboard.md` — the
> adapter and command files are generated per developer, not committed.

## Contributing

| | |
| --- | --- |
| Branch from | `develop` — `feature/<NNN>-<slug>` or `fix/<NNN>-<slug>` |
| Pull request title | Conventional Commits — `feat(014): password reset` |
| Merge | squash into `develop`; `develop` → `main` publishes |
| Release | automatic from `main`: a SemVer tag consumers can pin to |

Changing an `approved` spec obliges an amendment line and a word about who must
re-sync. See [`docs/lifecycle.md`](docs/lifecycle.md).

## License

<...>
