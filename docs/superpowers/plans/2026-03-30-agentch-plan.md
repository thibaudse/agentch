# AgentCh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that displays floating liquid glass pills representing active AI agent sessions, driven by Claude Code hooks over a local HTTP server.

**Architecture:** SwiftUI + AppKit hybrid. A single full-screen transparent NSPanel hosts a SwiftUI pill group view. An NWListener-based HTTP server receives hook events from Claude Code. A SessionManager ObservableObject is the shared state between the pill UI and the menu bar.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (NSPanel), Network framework (NWListener), macOS 26+ (liquid glass), SMAppService (launch at login)

---

## File Structure

```
AgentCh/
├── AgentCh.xcodeproj/
├── AgentCh/
│   ├── AgentChApp.swift              # App entry point, MenuBarExtra, AppDelegate
│   ├── Info.plist                     # LSUIElement = true (no dock icon)
│   ├── AgentCh.entitlements           # App Sandbox + network server
│   ├── Models/
│   │   ├── Session.swift             # Session, AgentType, SessionStatus models
│   │   └── SessionManager.swift      # ObservableObject managing session state
│   ├── Server/
│   │   └── EventServer.swift         # NWListener HTTP server on localhost:27182
│   ├── Hooks/
│   │   └── HookManager.swift         # Read/write ~/.claude/settings.json
│   ├── Window/
│   │   ├── AgentChPanel.swift        # NSPanel subclass (full-screen, transparent)
│   │   └── PillHostingView.swift     # NSHostingView with hitTest override
│   ├── Views/
│   │   ├── PillGroupView.swift       # Compact/expanded pill group with liquid glass
│   │   ├── MascotView.swift          # Animated mascot with state expressions
│   │   ├── MenuBarView.swift         # MenuBarExtra content
│   │   └── SettingsView.swift        # Settings window
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       └── ClaudeMascot.symbolset/   # Claude mascot SF Symbol or image set
├── AgentChTests/
│   ├── SessionTests.swift
│   ├── SessionManagerTests.swift
│   ├── EventServerTests.swift
│   └── HookManagerTests.swift
```

---

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `AgentCh.xcodeproj` (via `xcodebuild` / Swift Package)
- Create: `AgentCh/AgentChApp.swift`
- Create: `AgentCh/Info.plist`
- Create: `AgentCh/AgentCh.entitlements`

- [ ] **Step 1: Create the Xcode project**

Use Xcode's CLI or create a Swift Package-based app. Since we need AppKit integration, use an Xcode project:

```bash
cd /Users/thibaud/Projects/Personal/agentch
mkdir -p AgentCh/AgentCh
mkdir -p AgentCh/AgentChTests
```

Create `AgentCh/AgentCh/AgentChApp.swift`:

```swift
import SwiftUI

@main
struct AgentChApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AgentCh", systemImage: "bubble.left.and.bubble.right.fill") {
            Text("AgentCh is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — we're a menu bar-only app
    }
}
```

- [ ] **Step 2: Create Info.plist**

Create `AgentCh/AgentCh/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

`LSUIElement = true` hides the app from the Dock — menu bar only.

- [ ] **Step 3: Create entitlements**

Create `AgentCh/AgentCh/AgentCh.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

We need `network.server` for the HTTP listener, `network.client` for potential future use, and `files.user-selected.read-write` for reading `~/.claude/settings.json`.

- [ ] **Step 4: Create the Xcode project file**

```bash
cd /Users/thibaud/Projects/Personal/agentch
cat > Package.swift << 'PEOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentCh",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "AgentCh",
            path: "AgentCh/AgentCh"
        ),
        .testTarget(
            name: "AgentChTests",
            dependencies: ["AgentCh"],
            path: "AgentCh/AgentChTests"
        ),
    ]
)
PEOF
```

Note: We use `.macOS(.v15)` as the minimum in Package.swift since Swift PM doesn't yet have `.macOS(.v26)`. The liquid glass APIs require runtime macOS 26+ which we'll handle with `@available` checks. The actual deployment target is macOS 26.

- [ ] **Step 5: Build and verify the skeleton runs**

```bash
cd /Users/thibaud/Projects/Personal/agentch
swift build
```

Expected: builds successfully. The app won't run meaningfully from CLI since it needs a GUI context, but it should compile.

- [ ] **Step 6: Commit**

```bash
git add Package.swift AgentCh/
git commit -m "feat: scaffold AgentCh macOS menu bar app"
```

---

### Task 2: Session Model

**Files:**
- Create: `AgentCh/AgentCh/Models/Session.swift`
- Create: `AgentCh/AgentChTests/SessionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `AgentCh/AgentChTests/SessionTests.swift`:

```swift
import Testing
@testable import AgentCh

@Test func sessionCreation() {
    let session = Session(
        id: "abc123",
        agentType: .claude,
        label: "agentch/main",
        status: .idle,
        startedAt: Date()
    )
    #expect(session.id == "abc123")
    #expect(session.agentType == .claude)
    #expect(session.label == "agentch/main")
    #expect(session.status == .idle)
}

@Test func labelFromWorktree() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch-feat-auth",
        gitBranch: "feat/auth",
        isWorktree: true
    )
    #expect(label == "feat/auth")
}

@Test func labelFromBranch() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch",
        gitBranch: "develop",
        isWorktree: false
    )
    #expect(label == "agentch/develop")
}

@Test func labelFromMainBranch() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch",
        gitBranch: "main",
        isWorktree: false
    )
    #expect(label == "agentch")
}

@Test func labelFallbackNoGit() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch",
        gitBranch: nil,
        isWorktree: false
    )
    #expect(label == "agentch")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter SessionTests
```

Expected: FAIL — `Session` type not found.

- [ ] **Step 3: Implement the Session model**

Create `AgentCh/AgentCh/Models/Session.swift`:

```swift
import Foundation

enum AgentType: String, Codable, Sendable {
    case claude
    case codex
    case unknown
}

enum SessionStatus: String, Codable, Sendable {
    case thinking
    case idle
    case error
}

struct Session: Identifiable, Sendable {
    let id: String
    let agentType: AgentType
    var label: String
    var status: SessionStatus
    let startedAt: Date

    static let defaultBranches: Set<String> = ["main", "master"]

    static func deriveLabel(cwd: String, gitBranch: String?, isWorktree: Bool) -> String {
        let folderName = URL(fileURLWithPath: cwd).lastPathComponent

        guard let branch = gitBranch else {
            return folderName
        }

        if isWorktree {
            return branch
        }

        if defaultBranches.contains(branch) {
            return folderName
        }

        return "\(folderName)/\(branch)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter SessionTests
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add AgentCh/AgentCh/Models/Session.swift AgentCh/AgentChTests/SessionTests.swift
git commit -m "feat: add Session model with label derivation"
```

---

### Task 3: Session Manager

**Files:**
- Create: `AgentCh/AgentCh/Models/SessionManager.swift`
- Create: `AgentCh/AgentChTests/SessionManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `AgentCh/AgentChTests/SessionManagerTests.swift`:

```swift
import Testing
@testable import AgentCh

@Test @MainActor func addSession() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.count == 1)
    #expect(manager.sessions.first?.id == "s1")
    #expect(manager.sessions.first?.status == .idle)
    #expect(manager.sessions.first?.agentType == .claude)
}

@Test @MainActor func removeSession() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .sessionEnd,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.isEmpty)
}

@Test @MainActor func thinkingTransition() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .toolUse,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.first?.status == .thinking)
}

@Test @MainActor func stopTransition() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .toolUse,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .stop,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.first?.status == .idle)
}

@Test @MainActor func duplicateSessionStartIgnored() {
    let manager = SessionManager()
    let event = SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    )
    manager.handleEvent(event)
    manager.handleEvent(event)
    #expect(manager.sessions.count == 1)
}

@Test @MainActor func unknownSessionEventIgnored() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .toolUse,
        sessionId: "unknown",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter SessionManagerTests
```

Expected: FAIL — `SessionManager` and `SessionEvent` not found.

- [ ] **Step 3: Implement SessionManager**

Create `AgentCh/AgentCh/Models/SessionManager.swift`:

```swift
import Foundation
import SwiftUI

enum SessionEventType: String, Codable, Sendable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case toolUse = "tool_use"
    case stop = "stop"
}

struct SessionEvent: Codable, Sendable {
    let event: SessionEventType
    let sessionId: String
    let cwd: String
    let agentType: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case event
        case sessionId = "session_id"
        case cwd
        case agentType = "agent_type"
        case timestamp
    }
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []

    func handleEvent(_ event: SessionEvent) {
        switch event.event {
        case .sessionStart:
            guard !sessions.contains(where: { $0.id == event.sessionId }) else { return }
            let agentType = AgentType(rawValue: event.agentType) ?? .unknown
            let label = Session.deriveLabel(
                cwd: event.cwd,
                gitBranch: gitBranch(at: event.cwd),
                isWorktree: isGitWorktree(at: event.cwd)
            )
            let session = Session(
                id: event.sessionId,
                agentType: agentType,
                label: label,
                status: .idle,
                startedAt: event.timestamp
            )
            withAnimation(.spring(duration: 0.3)) {
                sessions.append(session)
            }

        case .sessionEnd:
            withAnimation(.spring(duration: 0.3)) {
                sessions.removeAll { $0.id == event.sessionId }
            }

        case .toolUse:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .thinking

        case .stop:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .idle
        }
    }

    private func gitBranch(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return branch?.isEmpty == true ? nil : branch
        } catch {
            return nil
        }
    }

    private func isGitWorktree(at path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--git-common-dir"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let commonDir = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // If git common dir differs from git dir, it's a worktree
            return commonDir != ".git" && !commonDir.isEmpty
        } catch {
            return false
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter SessionManagerTests
```

Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add AgentCh/AgentCh/Models/SessionManager.swift AgentCh/AgentChTests/SessionManagerTests.swift
git commit -m "feat: add SessionManager with event handling and status transitions"
```

---

### Task 4: HTTP Event Server

**Files:**
- Create: `AgentCh/AgentCh/Server/EventServer.swift`
- Create: `AgentCh/AgentChTests/EventServerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `AgentCh/AgentChTests/EventServerTests.swift`:

```swift
import Testing
import Foundation
@testable import AgentCh

@Test func parseSessionStartEvent() throws {
    let json = """
    {
        "event": "session_start",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "agent_type": "claude",
        "hook_event_name": "SessionStart",
        "timestamp": "2026-03-30T12:00:00Z"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .sessionStart)
    #expect(event.sessionId == "abc123")
    #expect(event.cwd == "/Users/thibaud/Projects/agentch")
    #expect(event.agentType == "claude")
}

@Test func parseToolUseEvent() throws {
    let json = """
    {
        "event": "tool_use",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "agent_type": "claude",
        "hook_event_name": "PreToolUse",
        "timestamp": "2026-03-30T12:00:01Z"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .toolUse)
}

@Test func parseStopEvent() throws {
    let json = """
    {
        "event": "stop",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "agent_type": "claude",
        "hook_event_name": "Stop",
        "timestamp": "2026-03-30T12:00:02Z"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .stop)
}

@Test func parseInvalidEventReturnsNil() {
    let json = "not json".data(using: .utf8)!
    #expect(throws: (any Error).self) {
        try EventServer.parseEvent(from: json)
    }
}

@Test func httpResponseFormat() {
    let response = EventServer.httpResponse(status: 200, body: "{\"ok\":true}")
    let responseStr = String(data: response, encoding: .utf8)!
    #expect(responseStr.contains("HTTP/1.1 200 OK"))
    #expect(responseStr.contains("Content-Type: application/json"))
    #expect(responseStr.contains("{\"ok\":true}"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter EventServerTests
```

Expected: FAIL — `EventServer` not found.

- [ ] **Step 3: Implement EventServer**

Create `AgentCh/AgentCh/Server/EventServer.swift`:

```swift
import Foundation
import Network

final class EventServer: Sendable {
    let port: UInt16
    private let listener: NWListener
    private let onEvent: @Sendable (SessionEvent) -> Void

    init(port: UInt16 = 27182, onEvent: @escaping @Sendable (SessionEvent) -> Void) throws {
        self.port = port
        self.onEvent = onEvent
        let params = NWParameters.tcp
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.newConnectionHandler = { [onEvent] connection in
            Self.handleConnection(connection, onEvent: onEvent)
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener.cancel()
    }

    private static func handleConnection(
        _ connection: NWConnection,
        onEvent: @escaping @Sendable (SessionEvent) -> Void
    ) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            defer { connection.cancel() }

            guard let data = data, error == nil else {
                return
            }

            // Extract body from HTTP request (after double CRLF)
            guard let body = Self.extractHTTPBody(from: data) else {
                let response = Self.httpResponse(status: 400, body: "{\"error\":\"invalid request\"}")
                connection.send(content: response, completion: .contentProcessed { _ in })
                return
            }

            do {
                let event = try Self.parseEvent(from: body)
                onEvent(event)
                let response = Self.httpResponse(status: 200, body: "{\"ok\":true}")
                connection.send(content: response, completion: .contentProcessed { _ in })
            } catch {
                let response = Self.httpResponse(status: 400, body: "{\"error\":\"invalid event\"}")
                connection.send(content: response, completion: .contentProcessed { _ in })
            }
        }
    }

    static func parseEvent(from data: Data) throws -> SessionEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionEvent.self, from: data)
    }

    static func extractHTTPBody(from data: Data) -> Data? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        guard let range = str.range(of: "\r\n\r\n") else {
            // Not an HTTP request — maybe raw JSON (for testing)
            return data
        }
        let bodyStr = String(str[range.upperBound...])
        return bodyStr.data(using: .utf8)
    }

    static func httpResponse(status: Int, body: String) -> Data {
        let statusText = status == 200 ? "OK" : "Bad Request"
        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        return Data(response.utf8)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter EventServerTests
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add AgentCh/AgentCh/Server/EventServer.swift AgentCh/AgentChTests/EventServerTests.swift
git commit -m "feat: add HTTP event server with NWListener"
```

---

### Task 5: Hook Manager

**Files:**
- Create: `AgentCh/AgentCh/Hooks/HookManager.swift`
- Create: `AgentCh/AgentChTests/HookManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `AgentCh/AgentChTests/HookManagerTests.swift`:

```swift
import Testing
import Foundation
@testable import AgentCh

@Test func installHooksIntoEmptySettings() throws {
    let empty: [String: Any] = [:]
    let result = try HookManager.mergeHooks(into: empty, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionEnd"]?.count == 1)
    #expect(hooks["PreToolUse"]?.count == 1)
    #expect(hooks["Stop"]?.count == 1)

    let url = hooks["SessionStart"]!.first!["url"] as! String
    #expect(url == "http://localhost:27182/events")
}

@Test func installHooksPreservesExistingHooks() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "command", "command": "echo hello"]
            ]
        ]
    ]
    let result = try HookManager.mergeHooks(into: existing, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    // Existing hook preserved + ours added
    #expect(hooks["SessionStart"]?.count == 2)
    #expect(hooks["SessionEnd"]?.count == 1)
}

@Test func installHooksSkipsDuplicates() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "http", "url": "http://localhost:27182/events"]
            ]
        ]
    ]
    let result = try HookManager.mergeHooks(into: existing, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    // Should not duplicate
    #expect(hooks["SessionStart"]?.count == 1)
}

@Test func uninstallHooksRemovesOnlyOurs() throws {
    let settings: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "command", "command": "echo hello"],
                ["type": "http", "url": "http://localhost:27182/events"]
            ],
            "SessionEnd": [
                ["type": "http", "url": "http://localhost:27182/events"]
            ]
        ]
    ]
    let result = HookManager.removeHooks(from: settings, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionStart"]?.first?["type"] as? String == "command")
    // SessionEnd had only our hook, so key should be empty array or removed
    #expect(hooks["SessionEnd"]?.isEmpty ?? true)
}

@Test func hookInstallationStatus() throws {
    let installed: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "http", "url": "http://localhost:27182/events"]
            ]
        ]
    ]
    #expect(HookManager.isInstalled(in: installed, port: 27182) == true)

    let notInstalled: [String: Any] = [:]
    #expect(HookManager.isInstalled(in: notInstalled, port: 27182) == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter HookManagerTests
```

Expected: FAIL — `HookManager` not found.

- [ ] **Step 3: Implement HookManager**

Create `AgentCh/AgentCh/Hooks/HookManager.swift`:

```swift
import Foundation

struct HookManager {
    static let hookEvents = ["SessionStart", "SessionEnd", "PreToolUse", "Stop"]

    static var settingsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }

    private static func agentChURL(port: UInt16) -> String {
        "http://localhost:\(port)/events"
    }

    // MARK: - Read/Write settings.json

    static func readSettings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: settingsPath)
        guard FileManager.default.fileExists(atPath: settingsPath) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    static func writeSettings(_ settings: [String: Any]) throws {
        let url = URL(fileURLWithPath: settingsPath)
        // Ensure .claude directory exists
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Install/Uninstall

    static func mergeHooks(into settings: [String: Any], port: UInt16) throws -> [String: Any] {
        var result = settings
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]
        let url = agentChURL(port: port)

        for event in hookEvents {
            var eventHooks = (hooks[event] as? [[String: Any]]) ?? []

            let alreadyExists = eventHooks.contains { hook in
                (hook["url"] as? String) == url
            }

            if !alreadyExists {
                eventHooks.append(["type": "http", "url": url])
            }

            hooks[event] = eventHooks
        }

        result["hooks"] = hooks
        return result
    }

    static func removeHooks(from settings: [String: Any], port: UInt16) -> [String: Any] {
        var result = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return result }
        let url = agentChURL(port: port)

        for event in hookEvents {
            guard var eventHooks = hooks[event] as? [[String: Any]] else { continue }
            eventHooks.removeAll { ($0["url"] as? String) == url }
            hooks[event] = eventHooks
        }

        result["hooks"] = hooks
        return result
    }

    static func isInstalled(in settings: [String: Any], port: UInt16) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        let url = agentChURL(port: port)

        return hookEvents.contains { event in
            guard let eventHooks = hooks[event] as? [[String: Any]] else { return false }
            return eventHooks.contains { ($0["url"] as? String) == url }
        }
    }

    // MARK: - High-level operations

    static func install(port: UInt16) throws {
        let settings = try readSettings()
        let updated = try mergeHooks(into: settings, port: port)
        try writeSettings(updated)
    }

    static func uninstall(port: UInt16) throws {
        let settings = try readSettings()
        let updated = removeHooks(from: settings, port: port)
        try writeSettings(updated)
    }

    static func checkInstalled(port: UInt16) -> Bool {
        guard let settings = try? readSettings() else { return false }
        return isInstalled(in: settings, port: port)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter HookManagerTests
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add AgentCh/AgentCh/Hooks/HookManager.swift AgentCh/AgentChTests/HookManagerTests.swift
git commit -m "feat: add HookManager for install/uninstall/status of Claude hooks"
```

---

### Task 6: NSPanel Window

**Files:**
- Create: `AgentCh/AgentCh/Window/AgentChPanel.swift`
- Create: `AgentCh/AgentCh/Window/PillHostingView.swift`

- [ ] **Step 1: Implement AgentChPanel**

Create `AgentCh/AgentCh/Window/AgentChPanel.swift`:

```swift
import AppKit

final class AgentChPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func coverScreen() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
    }
}
```

- [ ] **Step 2: Implement PillHostingView**

Create `AgentCh/AgentCh/Window/PillHostingView.swift`:

```swift
import AppKit
import SwiftUI

final class PillHostingView<Content: View>: NSHostingView<Content> {
    private var pillFrame: CGRect = .zero

    func updatePillFrame(_ frame: CGRect) {
        self.pillFrame = frame
        window?.ignoresMouseEvents = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only allow interaction within the pill group area
        if pillFrame.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add AgentCh/AgentCh/Window/
git commit -m "feat: add AgentChPanel and PillHostingView for transparent overlay"
```

---

### Task 7: Mascot View

**Files:**
- Create: `AgentCh/AgentCh/Views/MascotView.swift`

- [ ] **Step 1: Implement MascotView with state animations**

Create `AgentCh/AgentCh/Views/MascotView.swift`:

```swift
import SwiftUI

struct MascotView: View {
    let agentType: AgentType
    let status: SessionStatus
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            mascotShape
                .opacity(status == .idle ? 0.6 : 1.0)
                .scaleEffect(thinkingScale)
                .foregroundStyle(mascotColor)
        }
        .frame(width: size, height: size)
        .onChange(of: status) { _, newStatus in
            if newStatus == .thinking {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animationPhase = 1
                }
            } else {
                withAnimation(.spring(duration: 0.3)) {
                    animationPhase = 0
                }
            }
        }
    }

    private var thinkingScale: CGFloat {
        status == .thinking ? 1.0 + animationPhase * 0.1 : 1.0
    }

    private var mascotColor: Color {
        switch status {
        case .idle: return agentBaseColor
        case .thinking: return agentBaseColor
        case .error: return .red
        }
    }

    private var agentBaseColor: Color {
        switch agentType {
        case .claude: return .orange
        case .codex: return .green
        case .unknown: return .gray
        }
    }

    @ViewBuilder
    private var mascotShape: some View {
        switch agentType {
        case .claude:
            ClaudeMascotShape(status: status, animationPhase: animationPhase)
        case .codex:
            Image(systemName: "terminal.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
        }
    }
}

struct ClaudeMascotShape: View {
    let status: SessionStatus
    let animationPhase: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                // Claude spark/asterisk shape — simplified
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.4
                let armCount = 6
                let armWidth = radius * 0.28

                for i in 0..<armCount {
                    let baseAngle = (Double(i) / Double(armCount)) * .pi * 2 - .pi / 2
                    // Thinking: arms subtly rotate
                    let angle = baseAngle + (status == .thinking ? Double(animationPhase) * 0.15 : 0)

                    let endX = center.x + CGFloat(cos(angle)) * radius
                    let endY = center.y + CGFloat(sin(angle)) * radius

                    var path = Path()
                    path.addEllipse(in: CGRect(
                        x: (center.x + endX) / 2 - armWidth / 2,
                        y: (center.y + endY) / 2 - armWidth / 2,
                        width: armWidth,
                        height: radius
                    ).applying(
                        CGAffineTransform(translationX: -center.x, y: -center.y)
                            .concatenating(CGAffineTransform(rotationAngle: CGFloat(angle) + .pi / 2))
                            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
                    ))

                    context.fill(path, with: .color(.orange))
                }

                // Center circle — "eye" that pulses when thinking
                let eyeRadius = radius * (status == .thinking ? 0.22 + animationPhase * 0.05 : 0.2)
                let eyeRect = CGRect(
                    x: center.x - eyeRadius,
                    y: center.y - eyeRadius,
                    width: eyeRadius * 2,
                    height: eyeRadius * 2
                )
                context.fill(Path(ellipseIn: eyeRect), with: .color(.orange))
            }
            .frame(width: w, height: h)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git add AgentCh/AgentCh/Views/MascotView.swift
git commit -m "feat: add MascotView with Claude spark shape and state animations"
```

---

### Task 8: Pill Group View

**Files:**
- Create: `AgentCh/AgentCh/Views/PillGroupView.swift`

- [ ] **Step 1: Implement PillGroupView with compact/expanded states**

Create `AgentCh/AgentCh/Views/PillGroupView.swift`:

```swift
import SwiftUI

struct PillGroupView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var isHovering = false
    @State private var dragOffset: CGSize = .zero
    @State private var position: CGPoint = .zero
    @State private var hasSetInitialPosition = false

    private let compactMascotSize: CGFloat = 24
    private let expandedMascotSize: CGFloat = 20
    private let padding: CGFloat = 8
    private let spacing: CGFloat = 6

    var body: some View {
        if !sessionManager.sessions.isEmpty {
            pillContent
                .background(pillBackground)
                .onHover { hovering in
                    withAnimation(.spring(duration: 0.3)) {
                        isHovering = hovering
                    }
                }
                .gesture(dragGesture)
                .position(currentPosition)
                .onAppear {
                    if !hasSetInitialPosition {
                        loadOrDefaultPosition()
                        hasSetInitialPosition = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var pillContent: some View {
        HStack(spacing: spacing) {
            ForEach(sessionManager.sessions) { session in
                if isHovering {
                    expandedPill(for: session)
                } else {
                    MascotView(
                        agentType: session.agentType,
                        status: session.status,
                        size: compactMascotSize
                    )
                }
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding / 2)
    }

    @ViewBuilder
    private func expandedPill(for session: Session) -> some View {
        HStack(spacing: 4) {
            MascotView(
                agentType: session.agentType,
                status: session.status,
                size: expandedMascotSize
            )
            Text(session.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .glassEffect(.regular.interactive, in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                position.x += value.translation.width
                position.y += value.translation.height
                dragOffset = .zero
                savePosition()
            }
    }

    private var currentPosition: CGPoint {
        CGPoint(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
    }

    // MARK: - Position Persistence

    private func loadOrDefaultPosition() {
        if let savedX = UserDefaults.standard.object(forKey: "pillPositionX") as? CGFloat,
           let savedY = UserDefaults.standard.object(forKey: "pillPositionY") as? CGFloat {
            position = CGPoint(x: savedX, y: savedY)
        } else {
            // Default: top-center, below the notch
            if let screen = NSScreen.main {
                position = CGPoint(
                    x: screen.frame.midX,
                    y: screen.frame.maxY - screen.safeAreaInsets.top - 30
                )
            }
        }
    }

    private func savePosition() {
        UserDefaults.standard.set(position.x, forKey: "pillPositionX")
        UserDefaults.standard.set(position.y, forKey: "pillPositionY")
    }
}
```

Note: The `.glassEffect()` modifier requires macOS 26. If building against earlier SDK, this line should be wrapped with `if #available(macOS 26, *)`. Since our target is macOS 26+ this is fine.

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 3: Commit**

```bash
git add AgentCh/AgentCh/Views/PillGroupView.swift
git commit -m "feat: add PillGroupView with compact/expanded states and drag"
```

---

### Task 9: Menu Bar & Settings Views

**Files:**
- Create: `AgentCh/AgentCh/Views/MenuBarView.swift`
- Create: `AgentCh/AgentCh/Views/SettingsView.swift`

- [ ] **Step 1: Implement MenuBarView**

Create `AgentCh/AgentCh/Views/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var sessionManager: SessionManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false
    @State private var hooksInstalled: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        // Active sessions
        if sessionManager.sessions.isEmpty {
            Text("No active sessions")
                .foregroundStyle(.secondary)
        } else {
            ForEach(sessionManager.sessions) { session in
                HStack {
                    Circle()
                        .fill(statusColor(session.status))
                        .frame(width: 8, height: 8)
                    Text(session.label)
                    Spacer()
                    Text(session.agentType.rawValue)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Divider()

        // Hook status
        Text("Hooks: \(hookStatusText)")
            .foregroundStyle(.secondary)

        if hooksInstalled {
            Button(hooksDisabled ? "Enable Hooks" : "Disable Hooks") {
                hooksDisabled.toggle()
            }
            Button("Uninstall Hooks") {
                uninstallHooks()
            }
        } else {
            Button("Install Hooks") {
                installHooks()
            }
        }

        Divider()

        Button("Settings...") {
            SettingsWindowController.shared.showWindow()
        }

        Button("Quit AgentCh") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var hookStatusText: String {
        if !hooksInstalled { return "Not Installed" }
        return hooksDisabled ? "Installed & Disabled" : "Installed & Enabled"
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .thinking: return .green
        case .idle: return .gray
        case .error: return .red
        }
    }

    private func installHooks() {
        do {
            try HookManager.install(port: UInt16(httpPort))
            hooksInstalled = true
        } catch {
            print("Failed to install hooks: \(error)")
        }
    }

    private func uninstallHooks() {
        do {
            try HookManager.uninstall(port: UInt16(httpPort))
            hooksInstalled = false
        } catch {
            print("Failed to uninstall hooks: \(error)")
        }
    }
}
```

- [ ] **Step 2: Implement SettingsView and SettingsWindowController**

Create `AgentCh/AgentCh/Views/SettingsView.swift`:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }

            Section("Server") {
                TextField("HTTP Port", value: $httpPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Text("Requires app restart to take effect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pill Position") {
                Button("Reset to Default") {
                    UserDefaults.standard.removeObject(forKey: "pillPositionX")
                    UserDefaults.standard.removeObject(forKey: "pillPositionY")
                }
            }

            Section("Hooks") {
                Button("Reinstall Hooks") {
                    try? HookManager.install(port: UInt16(httpPort))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 300)
        .padding()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled // revert on failure
        }
    }
}

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgentCh Settings"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
swift build
```

Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add AgentCh/AgentCh/Views/MenuBarView.swift AgentCh/AgentCh/Views/SettingsView.swift
git commit -m "feat: add MenuBarView with hook management and SettingsView"
```

---

### Task 10: Wire Everything Together in AppDelegate

**Files:**
- Modify: `AgentCh/AgentCh/AgentChApp.swift`

- [ ] **Step 1: Update AgentChApp to wire all subsystems**

Replace the contents of `AgentCh/AgentCh/AgentChApp.swift` with:

```swift
import SwiftUI

@main
struct AgentChApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AgentCh", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarView(sessionManager: appDelegate.sessionManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let sessionManager = SessionManager()
    private var panel: AgentChPanel?
    private var eventServer: EventServer?
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        startServer()
        autoInstallHooksIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventServer?.stop()
    }

    private func setupPanel() {
        let panel = AgentChPanel()
        let pillView = PillGroupView(sessionManager: sessionManager)
        let hostingView = PillHostingView(rootView: pillView)
        hostingView.frame = panel.frame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.coverScreen()
        panel.orderFrontRegardless()
        self.panel = panel

        // Re-cover screen when display configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak panel] _ in
            panel?.coverScreen()
        }
    }

    private func startServer() {
        guard !hooksDisabled else { return }
        do {
            let server = try EventServer(port: UInt16(httpPort)) { [weak self] event in
                Task { @MainActor in
                    self?.sessionManager.handleEvent(event)
                }
            }
            server.start()
            self.eventServer = server
        } catch {
            print("Failed to start event server: \(error)")
        }
    }

    private func autoInstallHooksIfNeeded() {
        let port = UInt16(httpPort)
        if !HookManager.checkInstalled(port: port) {
            try? HookManager.install(port: port)
        }
    }
}
```

- [ ] **Step 2: Build to verify everything compiles together**

```bash
swift build
```

Expected: builds successfully with no errors.

- [ ] **Step 3: Commit**

```bash
git add AgentCh/AgentCh/AgentChApp.swift
git commit -m "feat: wire AppDelegate with panel, server, and session manager"
```

---

### Task 11: End-to-End Manual Test

**Files:** None — this is a verification task.

- [ ] **Step 1: Run the app**

```bash
cd /Users/thibaud/Projects/Personal/agentch
swift build && .build/debug/AgentCh &
```

Verify:
- Menu bar icon appears
- No dock icon (LSUIElement)
- No visible window (transparent panel)

- [ ] **Step 2: Simulate a session start event**

```bash
curl -X POST http://localhost:27182/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": "session_start",
    "session_id": "test-001",
    "cwd": "/Users/thibaud/Projects/Personal/agentch",
    "agent_type": "claude",
    "hook_event_name": "SessionStart",
    "timestamp": "2026-03-30T12:00:00Z"
  }'
```

Verify: A pill appears below the notch with a Claude mascot icon.

- [ ] **Step 3: Simulate thinking**

```bash
curl -X POST http://localhost:27182/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": "tool_use",
    "session_id": "test-001",
    "cwd": "/Users/thibaud/Projects/Personal/agentch",
    "agent_type": "claude",
    "hook_event_name": "PreToolUse",
    "timestamp": "2026-03-30T12:00:01Z"
  }'
```

Verify: Mascot animates (pulsing, brighter).

- [ ] **Step 4: Simulate stop**

```bash
curl -X POST http://localhost:27182/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": "stop",
    "session_id": "test-001",
    "cwd": "/Users/thibaud/Projects/Personal/agentch",
    "agent_type": "claude",
    "hook_event_name": "Stop",
    "timestamp": "2026-03-30T12:00:02Z"
  }'
```

Verify: Mascot returns to idle (dimmed, static).

- [ ] **Step 5: Hover over the pill**

Verify: Pill expands to show session label (e.g., `agentch/main`).

- [ ] **Step 6: Drag the pill**

Verify: Pill group is draggable. Position persists after release.

- [ ] **Step 7: Simulate a second session**

```bash
curl -X POST http://localhost:27182/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": "session_start",
    "session_id": "test-002",
    "cwd": "/Users/thibaud/Projects/myotherapp",
    "agent_type": "claude",
    "hook_event_name": "SessionStart",
    "timestamp": "2026-03-30T12:00:03Z"
  }'
```

Verify: Second mascot appears in the same pill group. Glass capsule expands.

- [ ] **Step 8: Simulate session end**

```bash
curl -X POST http://localhost:27182/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": "session_end",
    "session_id": "test-001",
    "cwd": "/Users/thibaud/Projects/Personal/agentch",
    "agent_type": "claude",
    "hook_event_name": "SessionEnd",
    "timestamp": "2026-03-30T12:00:04Z"
  }'
```

Verify: First mascot disappears, glass contracts. One mascot remains.

- [ ] **Step 9: End all sessions and verify cleanup**

```bash
curl -X POST http://localhost:27182/events \
  -H "Content-Type: application/json" \
  -d '{
    "event": "session_end",
    "session_id": "test-002",
    "cwd": "/Users/thibaud/Projects/myotherapp",
    "agent_type": "claude",
    "hook_event_name": "SessionEnd",
    "timestamp": "2026-03-30T12:00:05Z"
  }'
```

Verify: Pill group fades away entirely. Menu bar shows "No active sessions".

- [ ] **Step 10: Verify hook install/uninstall from menu**

Click menu bar icon → verify Install/Uninstall/Enable/Disable buttons work. Check `~/.claude/settings.json` after each operation.

- [ ] **Step 11: Commit any fixes from manual testing**

```bash
git add -A
git commit -m "fix: adjustments from end-to-end manual testing"
```

---

### Task 12: Run All Tests

- [ ] **Step 1: Run the full test suite**

```bash
cd /Users/thibaud/Projects/Personal/agentch
swift test
```

Expected: All tests pass (SessionTests, SessionManagerTests, EventServerTests, HookManagerTests).

- [ ] **Step 2: Commit if any test fixes needed**

```bash
git add -A
git commit -m "fix: test adjustments"
```
