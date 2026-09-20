---
name: drawing-wireframes
description: How this product's wireframes are drawn, and what they are allowed to decide. Use before drawing or editing a spec's wireframe.html, and when judging whether a drawn one is finished. Carries the notation, the breakpoints and the rules that a wireframe here must follow.
---

# Drawing wireframes

<!-- This is the starting point the template ships. It is yours from here:
develop it with your own notation, your component library and your breakpoints.
An upgrade will never overwrite it. -->

A wireframe answers one question: **where do the things a spec names sit on
screen?** It is not a design, and everything in it traces back to a requirement.

## Before drawing

- The spec is written first. The wireframe is drawn from it, never alongside it.
- If a product has no user interface, or this feature puts nothing on a screen,
  there is no wireframe. Skip it.
- Read `docs/templates/wireframe.html` for the notation and the pieces available.
  You draw the `<section>` elements only — `scripts/spec-wireframe.sh` puts the
  kit's head and tail around them. The head is the same in every wireframe, so
  retyping it decides nothing and risks a rule that silently stops applying.

## What goes in

- **One section per screen the spec names**, and no screen it does not.
- **Each state the spec calls for, drawn once**, at the breakpoint `AGENTS.md`
  names as the baseline — including the unhappy ones: empty, error, loading,
  permission-denied. A wireframe that only draws the happy path hides the half of
  the work that is hard.
- **The other breakpoints only where the layout itself changes.** A state that
  differs from another by a label, a value or a mark is the same arrangement, and
  redrawing it at every size teaches a reviewer nothing while costing the same as
  a frame that does. Draw real frames at the sizes you do draw; a content-height
  crop is not a screen.
- **The banner filled with this spec's path**, so a reviewer who opens the file
  alone knows what they are looking at.

## What stays out

Colour, typography, iconography and finished components. Grayscale and plainly
drawn, because **a wireframe that looks finished gets reviewed as a design
instead of a layout** — and then nobody argues with the arrangement, which is the
only thing it was for.

## The rule that matters most

**Every element traces to a requirement.** If you find yourself drawing something
no requirement asks for, the spec is incomplete: fix the spec. Do not invent a
requirement by drawing it — a screen is a very convincing way to smuggle in a
decision nobody approved.

Zones another spec owns are drawn as labelled context, never as content.

## Before calling it drawn

Read back the densest frame you drew — the one carrying the most at the smallest
size — and check it against the requirements it claims to trace to. That is the
one a mistake hides in.

That is the whole check. Do not open a browser, do not drive one, and do not
write a harness to measure geometry: a drawing worth forty frames turns "look at
every one" into an afternoon of building tooling, and the reviewer opens the file
anyway. Clipping and overlap are theirs to catch; arrangement and traceability
are yours.
