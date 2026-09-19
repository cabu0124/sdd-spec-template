# /sdd-upgrade — move this repository to a newer version of its template

**Goal.** Bring the scaffolding — scripts, command workflows, templates,
workflows — up to a published version of the template this repository was built
from, without touching the product.

Argument: optionally a version, `vX.Y.Z` or `latest`; empty means the version
pinned in `.sdd/template.yml`.

Reasoning: mechanical — a script decides every change, and a person reviews the
diff. Judgement only enters where it reports a conflict.

## What it will and will not touch

`.sdd/manifest.yml`, at the target version, sorts every file into three classes:

| Class | What happens |
| --- | --- |
| managed | Overwritten — unless this repository edited it, in which case it is reported and left alone |
| seeded | Never rewritten. Only the marked blocks (`sdd:rule1`) are refreshed |
| ignored | Never touched: `specs/`, the skills this repository wrote, its licence, its changelog |

**A managed file you edited is never merged.** It is reported as a conflict and
left exactly as it is. A merge the tool got wrong would be a change nobody
reviewed, in a file nobody was looking at.

## Steps

1. See what a newer version would change. It writes nothing:

    ```bash
    scripts/sdd-upgrade.sh --to latest
    ```

2. Read the changes before taking them:

    ```bash
    scripts/sdd-upgrade.sh --to latest --diff
    ```

3. Apply them into the working tree:

    ```bash
    scripts/sdd-upgrade.sh --to latest --apply
    ```

4. Read `git diff` and commit it yourself. The script never commits, never
  branches and never pushes.
5. Run `scripts/sdd-check.sh` and `scripts/sdd-doctor.sh`. An upgrade that
  breaks them is an upgrade to report, not to commit.
6. Work through whatever it reported as a conflict, by hand, one file at a
  time. `--diff` shows what the template now has; whether you want it is your
  call, and the reason you edited the file in the first place is the thing to
  weigh.
7. If the target version shipped migration notes, `--apply` prints them. They
  cover what copying a file cannot do — a generator that gained a tool, a
  convention that changed shape.

## The version is a pin

`.sdd/template.yml` records the version this repository is on, and nothing moves
until someone passes `--to`. A repository may sit on an old version
indefinitely; that is a decision, not drift.

```bash
scripts/sdd-upgrade.sh --list     # what the template has published
```

## A repository with no provenance

One built before any of this existed has no `.sdd/template.yml`. Record it once,
and the script works out which published version it is closest to:

```bash
scripts/sdd-upgrade.sh --adopt --source https://github.com/<org>/<template>.git
```

Pass `--from vX.Y.Z` when you know better than the guess. This matters more than
it looks: `.sdd/template.lock` has to record what the **template delivered**, not
what the repository holds now. Get it backwards and every local edit reads as up
to date, and the next upgrade overwrites it.

## Writes

`.sdd/template.yml`, `.sdd/template.lock`, and the managed files it says it will
write. Nothing under `specs/`, and no file in the `ignored` list. Never a commit.

## Stops when

`scripts/sdd-upgrade.sh` reports `Up to date`, `scripts/sdd-check.sh` passes, and
every conflict it reported has been dealt with or deliberately kept.
