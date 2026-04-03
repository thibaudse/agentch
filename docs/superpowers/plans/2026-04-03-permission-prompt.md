# Permission Prompt in Pill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to approve/deny Claude Code permission prompts directly from the agentch pill via a long-poll HTTP pattern.

**Architecture:** The hook script branches on event type — PreToolUse blocks on `POST /agentch/decision` waiting for the HTTP response, all other events fire-and-forget to `POST /agentch`. The EventServer holds PreToolUse connections open until the user decides (allow/deny in the pill) or the terminal resolves it (PostToolUse/SessionEnd). The pill UI shows tool name + input preview in a scrollable code block with allow/deny buttons.

**Tech Stack:** SwiftUI, NWListener (Network framework), bash hook script

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `agentch_pkg/agentch/Models/Session.swift` | Modify | Add `PermissionRequest` struct and `pendingPermission` field |
| `agentch_pkg/agentch/Models/SessionManager.swift` | Modify | Parse tool details, set `pendingPermission`, add `resolvePermission()`, auto-resolve on PostToolUse/SessionEnd |
| `agentch_pkg/agentch/Server/EventServer.swift` | Modify | New `/agentch/decision` endpoint, pending connections map, `resolveDecision()` |
| `agentch_pkg/agentch/Hooks/HookManager.swift` | Modify | Separate PreToolUse hook entry, update hook script with branching |
| `agentch_pkg/agentch/Views/PillGroupView.swift` | Modify | Permission UI in session row replacing AcknowledgeButton |
| `agentch_pkg/agentch/Views/AcknowledgeButton.swift` | Delete | No longer needed |
| `agentch_pkg/agentch/agentchApp.swift` | Modify | Wire resolvePermission callback |

---

### Task 1: Add PermissionRequest to Session model

**Files:**
- Modify: `agentch_pkg/agentch/Models/Session.swift`

- [ ] **Step 1: Add PermissionRequest struct and field**

At the end of `Session.swift`, before the closing brace of the file, add the struct. Also add `pendingPermission` to `Session`:

```swift
struct PermissionRequest: Sendable {
    let toolName: String
    let toolInput: String
}
```

Add to the `Session` struct, after the `tabTitle` field:

```swift
var pendingPermission: PermissionRequest?
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add agentch_pkg/agentch/Models/Session.swift
git commit -m "feat: add PermissionRequest model to Session"
```

---

### Task 2: Parse tool details in SessionEvent and update SessionManager

**Files:**
- Modify: `agentch_pkg/agentch/Models/SessionManager.swift`

- [ ] **Step 1: Add tool fields to SessionEvent**

Add two new optional fields to the `SessionEvent` struct (after the `tty` field):

```swift
var toolName: String?
var toolInput: String?
```

In the `SessionEvent.from(json:queryParams:)` method, parse these fields. After the `tty` assignment (line 41), add:

```swift
let toolName = json["tool_name"] as? String
let toolInput: String?
if let input = json["tool_input"] as? [String: Any] {
    // Format preview: show command for Bash, file_path for file tools, fallback to JSON
    if let command = input["command"] as? String {
        toolInput = command
    } else if let filePath = input["file_path"] as? String {
        toolInput = filePath
    } else if let data = try? JSONSerialization.data(withJSONObject: input, options: []),
              let str = String(data: data, encoding: .utf8) {
        toolInput = String(str.prefix(200))
    } else {
        toolInput = nil
    }
} else {
    toolInput = nil
}
```

Update the `return` statement to include the new fields:

```swift
return SessionEvent(
    event: event, sessionId: sessionId, cwd: cwd, agentType: agentType,
    termProgram: termProgram, termPid: termPid, tty: tty,
    toolName: toolName, toolInput: toolInput
)
```

- [ ] **Step 2: Add resolvePermission and onResolve callback**

Add a callback property and the resolve method to `SessionManager`. After the `cleanupTask` property:

```swift
var onResolvePermission: ((String, Bool) -> Void)?
```

Replace the `acknowledge` method with:

```swift
func resolvePermission(sessionId: String, allow: Bool) {
    guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
    sessions[index].pendingPermission = nil
    sessions[index].status = allow ? .thinking : .waiting
    onResolvePermission?(sessionId, allow)
}
```

- [ ] **Step 3: Update handleEvent for permission flow**

In `handleEvent`, update the `preToolUse` and `postToolUse` cases. Replace:

```swift
case .preToolUse, .postToolUse:
    guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
    sessions[index].status = .thinking
    updateTermInfo(at: index, from: event)
```

With:

```swift
case .preToolUse:
    guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
    sessions[index].status = .thinking
    updateTermInfo(at: index, from: event)

case .postToolUse:
    guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
    // Auto-resolve pending permission (user approved in terminal)
    if sessions[index].pendingPermission != nil {
        sessions[index].pendingPermission = nil
    }
    sessions[index].status = .thinking
    updateTermInfo(at: index, from: event)
```

In the `sessionEnd` case, add auto-resolve before removing the session:

```swift
case .sessionEnd:
    // Auto-resolve any pending permission
    if let index = sessions.firstIndex(where: { $0.id == event.sessionId }),
       sessions[index].pendingPermission != nil {
        resolvePermission(sessionId: event.sessionId, allow: true)
    }
    withAnimation(.spring(duration: 0.3)) {
        sessions.removeAll { $0.id == event.sessionId }
    }
```

- [ ] **Step 4: Add method to set pending permission**

Add a new method after `resolvePermission`:

```swift
func setPermission(sessionId: String, toolName: String, toolInput: String?) {
    guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
    sessions[index].pendingPermission = PermissionRequest(
        toolName: toolName,
        toolInput: toolInput ?? ""
    )
    let wasNotWaiting = sessions[index].status != .waiting
    sessions[index].status = .waiting
    if wasNotWaiting { SoundPlayer.playAttentionSound() }
}
```

- [ ] **Step 5: Build and verify**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add agentch_pkg/agentch/Models/SessionManager.swift
git commit -m "feat: parse tool details and add permission resolve flow"
```

---

### Task 3: Add decision endpoint to EventServer

**Files:**
- Modify: `agentch_pkg/agentch/Server/EventServer.swift`

- [ ] **Step 1: Add pending connections storage and resolve method**

Add a new property after `onEvent`. The EventServer needs a thread-safe way to store and retrieve pending connections. Add:

```swift
private let onDecisionEvent: @Sendable (SessionEvent) -> Void
private let pendingLock = NSLock()
private var _pendingConnections: [String: NWConnection] = [:]

private func storePending(sessionId: String, connection: NWConnection) {
    pendingLock.lock()
    _pendingConnections[sessionId] = connection
    pendingLock.unlock()
}

private func removePending(sessionId: String) -> NWConnection? {
    pendingLock.lock()
    let conn = _pendingConnections.removeValue(forKey: sessionId)
    pendingLock.unlock()
    return conn
}

func resolveDecision(sessionId: String, allow: Bool) {
    guard let connection = removePending(sessionId: sessionId) else { return }
    let body: String
    if allow {
        body = "{\"decision\":\"allow\"}"
    } else {
        body = "{\"decision\":\"deny\",\"reason\":\"Denied from AgentCh\"}"
    }
    let response = Self.httpResponse(status: 200, body: body)
    connection.send(content: response, completion: .contentProcessed { _ in
        connection.cancel()
    })
}
```

Note: `EventServer` is `Sendable` currently. The `_pendingConnections` dict and `NSLock` need to replace the `Sendable` conformance. Change the class declaration from:

```swift
final class EventServer: Sendable {
```

to:

```swift
final class EventServer: @unchecked Sendable {
```

- [ ] **Step 2: Update init to accept onDecisionEvent**

Update the initializer:

```swift
init(port: UInt16 = 27182, onEvent: @escaping @Sendable (SessionEvent) -> Void, onDecisionEvent: @escaping @Sendable (SessionEvent) -> Void) throws {
    self.port = port
    self.onEvent = onEvent
    self.onDecisionEvent = onDecisionEvent
    let params = NWParameters.tcp
    self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
}
```

- [ ] **Step 3: Route requests by path**

Update `handleConnection` to detect the URL path and route accordingly. The current code handles all POSTs the same. Replace the `handleConnection` method:

```swift
private static func handleConnection(
    _ connection: NWConnection,
    onEvent: @escaping @Sendable (SessionEvent) -> Void,
    onDecisionEvent: @escaping @Sendable (SessionEvent) -> Void,
    storePending: @escaping (String, NWConnection) -> Void
) {
    connection.start(queue: .global(qos: .userInitiated))
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
        guard let data = data, error == nil else {
            connection.cancel()
            return
        }

        let httpStr = String(data: data, encoding: .utf8) ?? ""
        let queryParams = Self.extractQueryParams(from: httpStr)
        let path = Self.extractPath(from: httpStr)

        guard let body = Self.extractHTTPBody(from: data) else {
            let response = Self.httpResponse(status: 400, body: "{\"error\":\"invalid request\"}")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        do {
            let event = try Self.parseEvent(from: body, queryParams: queryParams)

            if path == "/agentch/decision" {
                // Decision endpoint: hold connection open
                onDecisionEvent(event)
                storePending(event.sessionId, connection)
                // Do NOT respond — connection stays open
            } else {
                // Normal endpoint: fire and respond immediately
                onEvent(event)
                let response = Self.httpResponse(status: 200, body: "{\"ok\":true}")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        } catch {
            let response = Self.httpResponse(status: 400, body: "{\"error\":\"invalid event\"}")
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
```

- [ ] **Step 4: Add path extraction helper**

Add after `extractQueryParams`:

```swift
static func extractPath(from httpRequest: String) -> String {
    guard let firstLine = httpRequest.split(separator: "\r\n").first ?? httpRequest.split(separator: "\n").first,
          let urlPart = firstLine.split(separator: " ").dropFirst().first else {
        return "/"
    }
    let urlStr = String(urlPart)
    if let qIndex = urlStr.firstIndex(of: "?") {
        return String(urlStr[..<qIndex])
    }
    return urlStr
}
```

- [ ] **Step 5: Update start() to pass new parameters**

Update the `start()` method's `newConnectionHandler`:

```swift
func start() {
    listener.newConnectionHandler = { [onEvent, onDecisionEvent] connection in
        Self.handleConnection(
            connection,
            onEvent: onEvent,
            onDecisionEvent: onDecisionEvent,
            storePending: { [weak self] sessionId, conn in
                self?.storePending(sessionId: sessionId, connection: conn)
            }
        )
    }
    listener.start(queue: .global(qos: .userInitiated))
}
```

- [ ] **Step 6: Build and verify**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -10
```

This will fail because `agentchApp.swift` still uses the old `EventServer` init. That's expected — we fix it in Task 5.

- [ ] **Step 7: Commit**

```bash
git add agentch_pkg/agentch/Server/EventServer.swift
git commit -m "feat: add /agentch/decision endpoint with long-poll connection holding"
```

---

### Task 4: Update hook script and HookManager

**Files:**
- Modify: `agentch_pkg/agentch/Hooks/HookManager.swift`

- [ ] **Step 1: Update hook script to branch on event type**

Replace the `installScript()` method's `scriptContent` with:

```swift
let scriptContent = """
#!/bin/bash
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"
PORT="${AGENTCH_PORT:-27182}"
INPUT=$(cat)
SID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -z "$SID" ] && exit 0
TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)

# Save terminal window title for tab matching and session name
mkdir -p /tmp/agentch
if [ -n "$TERM_PROGRAM" ]; then
    case "$TERM_PROGRAM" in
        ghostty)         APP_NAME="Ghostty" ;;
        Apple_Terminal)  APP_NAME="Terminal" ;;
        iTerm.app)       APP_NAME="iTerm2" ;;
        WarpTerminal)    APP_NAME="Warp" ;;
        *)               APP_NAME="$TERM_PROGRAM" ;;
    esac
    /usr/bin/osascript -e "tell application \\"$APP_NAME\\" to return name of front window" \\
        > "/tmp/agentch/$SID" 2>/dev/null
fi

if [ "$EVENT" = "PreToolUse" ]; then
    # Decision endpoint: block and output response for Claude Code to read
    echo "$INPUT" | /usr/bin/curl -s -X POST "http://localhost:$PORT/agentch/decision?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY" \\
        -H 'Content-Type: application/json' --data-binary @- 2>/dev/null
else
    # Fire-and-forget for all other events
    echo "$INPUT" | /usr/bin/curl -s -X POST "http://localhost:$PORT/agentch?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY" \\
        -H 'Content-Type: application/json' --data-binary @- > /dev/null 2>&1 || true
fi
"""
```

Key difference: for PreToolUse, curl output is NOT piped to `/dev/null` — it goes to stdout so Claude Code reads the decision JSON.

- [ ] **Step 2: Update PreToolUse hook timeout**

In the `mergeHooks` method, change the hook entry to use a longer timeout for PreToolUse. Replace the hook creation block:

```swift
if !alreadyExists {
    let timeout: Int = (event == "PreToolUse") ? 300 : 5
    let ourHook: [String: Any] = [
        "type": "command",
        "command": hookCommand(port: port),
        "timeout": timeout,
    ]
    var matcherGroup: [String: Any] = [
        "hooks": [ourHook]
    ]
    // Claude requires "matcher" key; Codex works without it
    if agent == .claude {
        matcherGroup["matcher"] = ""
    }
    matcherGroups.append(matcherGroup)
}
```

- [ ] **Step 3: Build (will fail — EventServer init mismatch, expected)**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add agentch_pkg/agentch/Hooks/HookManager.swift
git commit -m "feat: hook script branches PreToolUse to decision endpoint, 300s timeout"
```

---

### Task 5: Wire everything in AppDelegate

**Files:**
- Modify: `agentch_pkg/agentch/agentchApp.swift`

- [ ] **Step 1: Update EventServer creation and wire callbacks**

In the `startServer()` method, update the `EventServer` initialization to pass the new `onDecisionEvent` callback. Replace the method:

```swift
private func startServer() {
    guard eventServer == nil else { return }
    do {
        let server = try EventServer(
            port: UInt16(httpPort),
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.sessionManager.handleEvent(event)
                }
            },
            onDecisionEvent: { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    // Auto-create session if needed
                    self.sessionManager.handleEvent(event)
                    // Set pending permission
                    if let toolName = event.toolName {
                        self.sessionManager.setPermission(
                            sessionId: event.sessionId,
                            toolName: toolName,
                            toolInput: event.toolInput
                        )
                    }
                }
            }
        )
        server.start()
        self.eventServer = server
    } catch {
        NSLog("[agentch] Failed to start server: %@", error.localizedDescription)
    }
}
```

- [ ] **Step 2: Wire resolvePermission callback**

In `applicationDidFinishLaunching`, after the existing `SettingsWindowController` wiring, add:

```swift
sessionManager.onResolvePermission = { [weak self] sessionId, allow in
    self?.eventServer?.resolveDecision(sessionId: sessionId, allow: allow)
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add agentch_pkg/agentch/agentchApp.swift
git commit -m "feat: wire EventServer decision endpoint to SessionManager permission flow"
```

---

### Task 6: Update pill UI with permission prompt

**Files:**
- Modify: `agentch_pkg/agentch/Views/PillGroupView.swift`
- Delete: `agentch_pkg/agentch/Views/AcknowledgeButton.swift`

- [ ] **Step 1: Replace AcknowledgeButton with permission UI in sessionRow**

In `PillGroupView.swift`, find the block in `sessionRow` that shows the AcknowledgeButton (lines 222-229):

```swift
if session.status == .waiting {
    AcknowledgeButton {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            sessionManager.acknowledge(sessionId: session.id)
        }
    }
    .transition(.blurReplace)
}
```

Replace it with:

```swift
if let permission = session.pendingPermission {
    PermissionPromptView(
        permission: permission,
        scale: scale,
        onAllow: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sessionManager.resolvePermission(sessionId: session.id, allow: true)
            }
        },
        onDeny: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sessionManager.resolvePermission(sessionId: session.id, allow: false)
            }
        }
    )
    .transition(.blurReplace)
}
```

- [ ] **Step 2: Add PermissionPromptView**

Add at the end of `PillGroupView.swift` (before the `ExpansionAnchor` struct):

```swift
struct PermissionPromptView: View {
    let permission: PermissionRequest
    let scale: CGFloat
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(permission.toolName)
                .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)

            if !permission.toolInput.isEmpty {
                ScrollView {
                    Text(permission.toolInput)
                        .font(.system(size: 9 * scale, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6 * scale)
                }
                .frame(maxHeight: 60 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                        .fill(.primary.opacity(0.06))
                )
            }

            HStack(spacing: 6 * scale) {
                Button("Allow") { onAllow() }
                    .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
                    .buttonStyle(.plain)
                    .cursor(.pointingHand)

                Button("Deny") { onDeny() }
                    .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .cursor(.pointingHand)
            }
        }
    }
}
```

- [ ] **Step 3: Delete AcknowledgeButton.swift**

```bash
rm agentch_pkg/agentch/Views/AcknowledgeButton.swift
```

- [ ] **Step 4: Remove acknowledge method reference**

In `SessionManager.swift`, the old `acknowledge` method was already replaced by `resolvePermission` in Task 2. Verify no remaining references:

```bash
cd /Users/thibaud/Projects/Personal/agentch && grep -rn "acknowledge\|AcknowledgeButton" agentch_pkg/agentch/
```

Expected: No matches (or only in the deleted file).

- [ ] **Step 5: Build and verify**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add agentch_pkg/agentch/Views/PillGroupView.swift agentch_pkg/agentch/agentchApp.swift
git rm agentch_pkg/agentch/Views/AcknowledgeButton.swift
git commit -m "feat: permission prompt UI in pill with allow/deny buttons"
```

---

### Task 7: Reinstall hooks and test end-to-end

**Files:**
- None (testing only)

- [ ] **Step 1: Build clean**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```

- [ ] **Step 2: Reinstall hooks with new script**

```bash
cd /Users/thibaud/Projects/Personal/agentch && swift run &
sleep 2
# The app auto-installs hooks on launch, but force reinstall to get the new script:
curl -s -X POST "http://localhost:27182/agentch" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"SessionStart","session_id":"test-hook","cwd":"/tmp"}'
```

Or open Settings → Hooks → Install All.

- [ ] **Step 3: Verify hook script was updated**

```bash
cat ~/.agentch/hook.sh | grep "PreToolUse"
```

Expected: Should show the `if [ "$EVENT" = "PreToolUse" ]` branching logic.

- [ ] **Step 4: Test decision endpoint with simulated events**

```bash
# Start a session
curl -s -X POST "http://localhost:27182/agentch" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"SessionStart","session_id":"test-perm","cwd":"/tmp"}'

# Send PreToolUse to decision endpoint (this will BLOCK in the foreground)
curl -s -X POST "http://localhost:27182/agentch/decision" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"PreToolUse","session_id":"test-perm","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' &

# The pill should show the permission prompt. Click Allow in the pill.
# The curl command should receive {"decision":"allow"} and exit.

# Clean up
curl -s -X POST "http://localhost:27182/agentch" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"SessionEnd","session_id":"test-perm","cwd":"/tmp"}'
```

- [ ] **Step 5: Test terminal auto-resolve**

```bash
# Start session and send PreToolUse
curl -s -X POST "http://localhost:27182/agentch" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"SessionStart","session_id":"test-auto","cwd":"/tmp"}'
curl -s -X POST "http://localhost:27182/agentch/decision" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"PreToolUse","session_id":"test-auto","cwd":"/tmp","tool_name":"Edit","tool_input":{"file_path":"/tmp/test.txt"}}' &

sleep 1

# Simulate terminal approval (PostToolUse)
curl -s -X POST "http://localhost:27182/agentch" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"PostToolUse","session_id":"test-auto","cwd":"/tmp"}'

# The blocked curl should receive {"decision":"allow"} and exit
# The pill should clear the permission UI

# Clean up
curl -s -X POST "http://localhost:27182/agentch" -H 'Content-Type: application/json' \
  -d '{"hook_event_name":"SessionEnd","session_id":"test-auto","cwd":"/tmp"}'
```
