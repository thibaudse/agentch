# 03 — Hooks And Session Routing

## Hook Files

- Stop: `scripts/hooks/claude-show.sh`
- PermissionRequest: `scripts/hooks/claude-permission.sh`
- UserPromptSubmit: `scripts/hooks/claude-dismiss.sh`
- Config: `hooks/claude-code/hooks.json`

## Session Identity

All Claude hook payloads include `session_id`.
Always propagate this value through:

- `scripts/island.sh` command payloads
- `IslandCommand` decode model
- `IslandPanelController` methods

## Queue Contract

- If a blocking prompt is active, new blocking prompt commands queue.
- Queue items are session-tagged.
- If same-session queued item arrives later, it replaces prior queued item for that session.

## Dismiss Contract

- `dismiss(session_id)` should only affect matching session.
- If target session is queued, remove it from queue and complete its pipe with cancel payload.
- If target session is active, dismiss active prompt normally.

## Response Semantics

Interactive prompt:

- submit -> write text to pipe
- dismiss -> write `__dismiss__`

Permission/Elicitation:

- allow/deny/suggestion -> JSON/decision payload as expected by hook script
- dismiss -> deny-equivalent output

## Timeout Safety

- Stop hook waits on FIFO with timeout (`AGENTCH_STOP_TIMEOUT_SECS`, default `590`).
- Permission/Elicitation waits with timeout (`AGENTCH_PERMISSION_TIMEOUT_SECS`, default `110`).
- On timeout or termination signal, hooks dismiss the same `session_id` notch and return safe fallback.

## UserPromptSubmit Safety

User terminal submit must call session-scoped dismiss hook (`claude-dismiss.sh`) to avoid cross-session UI dismissal.
