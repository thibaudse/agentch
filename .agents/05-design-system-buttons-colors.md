# 05 — Design System, Buttons, Colors

## Palette

Use Claude brand palette only:

- primary `#C15F3C`
- secondary `#B1ADA1`
- neutral support `#F4F3EE`, `#FFFFFF`

No non-brand accent palettes.

## Button Variants

The design system exposes only:

- `primary`
- `secondary`

Rules:

- `primary`: filled accent, white text/icon, accent stroke.
- `secondary`: transparent fill, secondary stroke, secondary text/icon.

All buttons in `IslandView` must use `DSSendButton`, `DSHeaderButton`, or `DSPillButton` with one of these variants.

## Status And Sender Colors

- Header status dot: session primary color.
- Conversation tags:
  - `Claude` -> primary
  - `You` -> secondary

## Input Styling

- TextField focus ring and tint use session primary/secondary pair.
- Keep shell and surfaces dark; do not reintroduce glass effects.

## Permission Preview Header

- `File:` and `replace_all:` are metadata, shown above the numbered diff block.
- Metadata rows are not line-numbered.
- File path control is plain (no pill) with accent tint and hand cursor on hover.
- Clicking the file path should open the target file in IDE/default editor.
