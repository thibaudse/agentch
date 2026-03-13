# 01 — Product And Constraints

## Product Goal

`agentch` is a notch-anchored assistant UI for Claude on macOS.
It appears when Claude needs user action, supports typed responses, permission decisions, and elicitation answers.

## Scope

- Claude-only.
- Keep all product naming as `agentch`.
- Do not add integrations or labels for other CLIs.

## Visual Constraints

- Island shell must remain pure black.
- Host panel background remains clear.
- Notch shell can morph/animate, but should keep notch-attached feel.
- Content must render below notch-safe area; no clipping into hardware notch zone.

## Interaction Constraints

- Blocking prompts must be session-safe.
- Session `dismiss` must be scoped by `session_id`.
- If multiple sessions request blocking prompts, active prompt stays active and others queue.

## Input/Output Behavior

- Stop hook is synchronous and waits on FIFO.
- Notch submit writes to the response pipe and unblocks the hook.
- Dismiss writes `__dismiss__` for interactive prompts.
- Permission/Elicitation dismiss resolves as deny-equivalent response.

## Required Color Rules

- Claude primary: `#C15F3C`
- Claude secondary: `#B1ADA1`
- Supporting neutrals: `#F4F3EE`, `#FFFFFF`
- Header status dot uses session primary color.
- Conversation sender tags:
  - `Claude` -> primary
  - `You` -> secondary

## Button Rules

Exactly two styles:

- `primary`
  - filled with accent
  - foreground white
- `secondary`
  - clear fill
  - secondary-color stroke/foreground

No ad-hoc one-off button styling in views.
