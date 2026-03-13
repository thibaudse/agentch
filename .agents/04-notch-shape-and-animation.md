# 04 — Notch Shape And Animation

## Shape

- Shell shape is custom (`IslandShellShape`), not default rounded rectangle.
- Shape uses animatable top and bottom radii.
- Top seam overlay (1px) reduces edge artifacts during morph.

## Open/Close Motion

- Notch open: spring (`response: 0.42`, `dampingFraction: 0.80`)
- Notch close: spring (`response: 0.45`, `dampingFraction: 1.0`)

## Content Choreography

- Show flow: notch opens first, then content appears.
- Hide flow: content fades first, then notch closes.

## Header Synchronization

- Header controls animate with the same content visibility gate.
- Expand/collapse should feel horizontal and coherent with width changes.

## Panel Behavior During Motion

- Keep host panel frame fixed during notch animation.
- Avoid frame resize choreography to reduce redraw jitter.

## Hit Targets

- Header action controls (expand + dismiss) use explicit content shape so full visual button area is clickable.
