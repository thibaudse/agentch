# Permission Prompt in Pill

## Overview

Allow users to approve/deny Claude Code permission prompts directly from the expanded agentch pill, without switching to the terminal. Uses a long-poll HTTP pattern where the hook script blocks until the user decides.

## Hook Script Changes

The hook script branches based on `hook_event_name`:

- **PreToolUse**: Sends event to `POST /agentch/decision` and **blocks** waiting for the HTTP response. Outputs the response JSON (`{"decision":"allow"}` or `{"decision":"deny","reason":"Denied from AgentCh"}`) to stdout for Claude Code to read.
- **All other events**: Fire-and-forget as today — `POST /agentch`, output to `/dev/null`.

PreToolUse gets its own separate hook entry in Claude settings with no timeout (or very large, e.g., `"timeout": 300`). All other events keep `"timeout": 5`.

## Server Changes

New endpoint: `POST /agentch/decision`

1. Parse PreToolUse event (tool name, input parameters, session ID)
2. Call event handler to update session with permission UI
3. Hold the TCP connection open — do not respond
4. Store the connection keyed by session ID in a `[String: NWConnection]` pending decisions map
5. When user clicks allow/deny or the decision is resolved externally, look up the connection and send the response JSON

The existing `POST /agentch` endpoint is unchanged.

`EventServer` exposes `resolveDecision(sessionId:, allow:)` which sends the response on the held connection and removes it from the pending map.

## Session Model Changes

New optional field on `Session`:

```swift
var pendingPermission: PermissionRequest?
```

New struct:

```swift
struct PermissionRequest {
    let toolName: String
    let toolInput: String  // formatted preview of arguments
}
```

Tool input formatting: for Bash show `command`, for Edit show `file_path`, for Write show `file_path`, fallback to truncated raw JSON.

`pendingPermission` is set when a PreToolUse arrives via `/agentch/decision`. Cleared when allow/deny is clicked or terminal resolves it.

## Pill UI Changes

In the expanded session row, when `session.pendingPermission` is non-nil:

- **Tool name** in bold (e.g., "Bash")
- **Preview text** below in a monospaced code block: dark background (`.primary.opacity(0.06)`), rounded corners, small horizontal padding. Wrapped in a `ScrollView` capped at ~4 lines (~60pt). Shrinks to fit if shorter.
- **Two buttons** below: "Allow" (accent color) and "Deny" (secondary), plain text style, side by side

When `pendingPermission` is nil and status is `.waiting`, the row shows "needs input" status label only.

`AcknowledgeButton` is removed entirely.

## SessionManager Changes

New method: `resolvePermission(sessionId:, allow:)`

1. Clears `session.pendingPermission`
2. Sets status to `.thinking` (if allowed) or keeps `.waiting` (if denied)
3. Calls through to `EventServer.resolveDecision(sessionId:, allow:)` to send the HTTP response

`AppDelegate` wires `SessionManager` and `EventServer` together for this callback.

Auto-resolve: when `PostToolUse` or `SessionEnd` arrives and a pending decision exists for that session, auto-resolve as "allow" (user handled it in terminal). The held connection gets a response and the hook script exits cleanly.

## Files to Modify

| File | Change |
|---|---|
| `Hooks/HookManager.swift` | Separate PreToolUse hook entry, update hook script with branching logic, remove timeout for PreToolUse |
| `Server/EventServer.swift` | New `/agentch/decision` endpoint, pending connections map, `resolveDecision()` method |
| `Models/Session.swift` | Add `PermissionRequest` struct and `pendingPermission` field |
| `Models/SessionManager.swift` | Parse tool details from PreToolUse, set `pendingPermission`, add `resolvePermission()`, auto-resolve on PostToolUse/SessionEnd |
| `Views/PillGroupView.swift` | Permission UI in session row (tool name, code block preview, allow/deny buttons) |
| `Views/AcknowledgeButton.swift` | Delete entirely |
| `agentchApp.swift` | Wire `resolvePermission` callback between SessionManager and EventServer |

## New @AppStorage Keys

None.

## Testing

- Verify PreToolUse hook blocks and outputs decision JSON
- Verify pill shows tool name + preview when permission is pending
- Verify "Allow" sends `{"decision":"allow"}` and resumes Claude
- Verify "Deny" sends `{"decision":"deny","reason":"Denied from AgentCh"}` and Claude handles it
- Verify answering in terminal auto-resolves the pending decision (PostToolUse clears it)
- Verify session end cleans up pending decisions
- Verify scroll view works for long tool inputs
- Verify non-permission waits (Stop) show plain status without approve/deny
