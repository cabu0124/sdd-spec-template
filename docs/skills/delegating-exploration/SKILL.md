---
name: delegating-exploration
description: When to hand reading to a subagent and when to do it yourself. Use before any step that would read many files to decide one thing — surveying existing specs, locating where a change belongs, comparing several documents. Also use when a subagent looks like the obvious move, to check it is not the expensive one.
---

# Delegating exploration

A subagent reads on your behalf and reports back. What it read never enters this
conversation — and that is the whole point, because everything in this
conversation is re-read on every single call that follows.

That is also why delegating is not free, and not always right.

## Delegate when

- The exploration will take more than three or four tool calls.
- You need **conclusions**, not the material: which files matter, what convention
  they follow, what contradicts what.
- The material is large and you will not quote it.

Ask for a short report and say so explicitly. A subagent that returns everything
it read has moved nothing — it has duplicated it.

## Do it yourself when

1. **You will need the material verbatim.** If you are going to edit those files
   or quote them, you are loading them either way.
2. **The task is small.** Two files is cheaper to read than to explain.
3. **You are going to iterate.** This is the one people get wrong. Each
   invocation starts a fresh context and reloads whatever it needs; in this
   conversation the same files stay cached after the first read. Delegate the
   first pass, then iterate here.
4. **The answer depends on the conversation.** A subagent cannot see what the
   user just said, or what you decided three turns ago.

## Asking well

Name what you want back, and cap it. "Tell me which specs overlap and quote the
requirement" beats "look at the specs". The report is what you pay for, so
specify it.

When a subagent writes a file instead of returning its contents, say that too —
it is the difference between moving work out of this context and copying it in.

## The cost this is really about

Every call re-reads this conversation. A file that never enters it is not saved
once; it is saved on every call that comes after. That compounds — and so does
the opposite.
