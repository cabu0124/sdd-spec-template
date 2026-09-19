---
name: reading-condensed-output
description: How to read the condensed output this repository's commands produce, and how to get back the part that was cut. Use when a command's output carries a recall id, a (xN) repetition count or an elided-lines marker, or when output looks shorter than expected.
---

# Reading condensed output

Commands in this repository are routed through `scripts/sdd-compact.sh` before
their output reaches you. It removes what nobody reads and keeps what decides.
Nothing is lost: everything cut is still one command away.

## The three markers

| You see | It means |
| --- | --- |
| `some line  (x4)` | That line appeared 4 times. It is not 4 different results. |
| `... 137 line(s) elided ...` | The head and the tail are shown; the middle was dropped. |
| `[full output: scripts/sdd-recall.sh 20260918-174406-21640]` | The full, unmodified output is stored. Run that command to read it. |

## When to reach for the full output

Run the `scripts/sdd-recall.sh <id>` line **verbatim**, as printed. Do it when:

- A command failed and the condensed output does not say why.
- You need a line from the middle of something that was elided.
- A diff was summarised to a file list and you have to read the change itself.

Do **not** re-run the original command to see more. It costs a second execution
and the output is already stored. A recall is a file read.

## What is never condensed

- Reading a file. `cat`, `head` and `tail` are deliberately off the rewrite
  allowlist: truncating what you are trying to read is how a wrong edit is made.
- CI annotations (`::error file=...::`). They are the lines worth reading.
- Anything, when `--verbose` is passed. `scripts/sdd-check.sh --verbose` and
  `scripts/sdd-compact.sh --verbose <cmd>` print everything, unchanged.

## What this costs you

A condensed `git diff` tells you which files changed and by how much, not what
changed in them. If the change itself is what you need, recall it or run
`git diff --verbose` through the compactor. Summarising a diff you were about to
reason about is the one failure mode here — recall is the fix, not guessing.
