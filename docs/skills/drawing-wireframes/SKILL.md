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
- Start from `docs/templates/wireframe.html`: it carries the notation and the
  pieces available. Copy it into the spec's directory.

## What goes in

- **One section per screen the spec names**, and no screen it does not.
- **Every breakpoint the product supports**, as declared in `AGENTS.md`. Draw
  real frames at those sizes; a content-height crop is not a screen.
- **The states the spec calls for**, including the unhappy ones — empty, error,
  loading, permission-denied. A wireframe that only draws the happy path hides
  the half of the work that is hard.
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

Open every frame and every required state in a browser, offline, and look for
clipping, overlap and illegibility. `scripts/spec-check.sh` validates the spec;
nothing validates HTML geometry but your eyes.
