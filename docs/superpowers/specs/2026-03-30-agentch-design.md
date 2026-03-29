# AgentCh — Design Spec

A macOS menu bar app that displays floating glass pills representing active AI agent sessions (Claude Code, with future support for Codex and others). Pills show animated mascots per session, grouped in a single draggable liquid glass capsule.

## Architecture

Three subsystems:

1. **Session Manager** — Tracks active agent sessions. Receives events via a local HTTP server. Source of truth for all session state. Implemented as an `ObservableObject` shared across the UI.

2. **Pill Window System** — A single full-screen transparent `NSPanel` hosting all pills in one liquid glass group. Click-through everywhere except the pill group itself.

3. **Menu Bar UI** — `MenuBarExtra` providing settings, session list, hook management, and quit.

### Data Flow

```
Claude hooks (HTTP POST) → Local HTTP Server → Session Manager → Pill Window (SwiftUI)
                                                               → Menu Bar UI (SwiftUI)
```

## Session Model

```swift
struct Session: Identifiable {
    let id: String              // from hook's session_id
    let agentType: AgentType    // .claude | .codex | .unknown
    var label: String           // derived identifier
    var status: SessionStatus   // .thinking | .idle | .error
    let startedAt: Date
}

enum AgentType {
    case claude
    case codex
    case unknown
}

enum SessionStatus {
    case thinking
    case idle
    case error
}
```

### Label Derivation

From the hook's `cwd` field, in priority order:

1. If inside a git worktree → worktree name (e.g., `feat/auth`)
2. If on a non-default branch → `folder/branch` (e.g., `agentch/main`)
3. Fallback → folder name only (e.g., `agentch`)

### Status Transitions

| Hook Event   | Effect                                    |
|-------------|-------------------------------------------|
| `SessionStart` | Create session, status = `.idle`        |
| `PreToolUse`   | Status → `.thinking`                    |
| `Stop`         | Status → `.idle`                        |
| `SessionEnd`   | Remove session, pill disappears         |

## Pill Window System

### Full-Screen Transparent Window

A single `NSPanel` subclass (`AgentChPanel`) covering the entire screen:

- `level = .floating`
- `backgroundColor = .clear`, `isOpaque = false`
- `styleMask = [.borderless, .nonactivatingPanel]`
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`
- `hidesOnDeactivate = false`
- `ignoresMouseEvents = true` at the window level
- Mouse events re-enabled only over the pill group region via `hitTest` override on the hosting view (returns `nil` for non-pill areas)

### Pill Group

All pills live in a single group — always together, never separated.

**Compact mode (default):**
- Shows only mascot icons, one per session, side by side (~24x24pt each)
- Each mascot animates independently based on its session status
- Liquid glass capsule wraps tightly around the icons
- Extremely minimal footprint

**Hover / expanded mode:**
- Hovering over the group expands it to reveal session details
- Each session shows: mascot + label (e.g., `agentch/main`)
- Glass background morphs smoothly to the wider size
- Mouse leave → contracts back to compact with spring animation

**Dragging:**
- Grab anywhere on the group to drag the entire thing
- Position persisted to `UserDefaults`
- Default position: top-center, just below `screen.safeAreaInsets.top` (below the notch)

**Adding a session:**
- New mascot slides in with a spring animation
- Glass capsule expands fluidly

**Removing a session:**
- Mascot shrinks/fades out
- Glass capsule contracts
- Last session removed → group fades away entirely

### Liquid Glass Styling

- macOS 26 native liquid glass API (`.glassEffect()` modifier)
- Capsule clip shape on the group
- Subtle shadow for depth

## Claude Mascot & Animations

### Mascot Asset

- Claude logo/icon — stylized spark or simplified avatar
- SVG or asset catalog for crisp rendering at any size
- ~24x24pt in compact mode

### Session States

| Status      | Visual                                                                 |
|------------|------------------------------------------------------------------------|
| `.idle`     | Static mascot, resting expression, slightly dimmed                    |
| `.thinking` | Eyes/sparkle animate — pulsing sparkle, shifting gaze, subtle bounce. Fully bright |
| `.error`    | Mascot tinted red/orange, static                                      |

### Animation Approach

- SwiftUI `TimelineView` or `withAnimation(.repeatForever)` for thinking loop
- Spring animations (~0.3s) for state transitions
- Each mascot animates independently
- Pure SwiftUI shape/path animations — no Lottie or heavy frameworks

### Future Agent Icons

- `.claude` → Claude mascot
- `.codex` → OpenAI icon
- `.unknown` → generic agent glyph

## HTTP Server & Hook Integration

### Local HTTP Server

- Built with Swift `NWListener` (Network framework, no dependencies)
- Listens on `localhost:27182` (configurable in settings)
- Single endpoint: `POST /events`

### Event Payload

```json
{
    "event": "session_start|session_end|tool_use|stop",
    "session_id": "abc123",
    "cwd": "/Users/thibaud/Projects/agentch",
    "agent_type": "claude",
    "timestamp": "2026-03-30T12:00:00Z"
}
```

### Hook Installation

Automatic on first launch (or via menu bar "Install" button):

- Reads `~/.claude/settings.json`
- Merges hook entries for: `SessionStart`, `SessionEnd`, `PreToolUse`, `Stop`
- Each hook is type `http` pointing to `http://localhost:27182/events`
- Preserves existing user hooks — appends, never overwrites
- Skips if hooks already present

### Hook Config Added to `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart": [{ "type": "http", "url": "http://localhost:27182/events" }],
    "SessionEnd": [{ "type": "http", "url": "http://localhost:27182/events" }],
    "PreToolUse": [{ "type": "http", "url": "http://localhost:27182/events" }],
    "Stop": [{ "type": "http", "url": "http://localhost:27182/events" }]
  }
}
```

### Hook States

Four states managed via menu bar:

- **Install** — writes hooks to `~/.claude/settings.json`
- **Uninstall** — removes AgentCh hooks from `~/.claude/settings.json`
- **Enable** — hooks are present and active
- **Disable** — hooks remain in settings.json but the app's HTTP server stops accepting connections (events are silently dropped). The hooks config stays intact so re-enabling is instant. Disable state is tracked in the app's own `UserDefaults`, not in Claude's settings file.

### Resilience

- If the app isn't running when a hook fires, the HTTP request fails silently (Claude Code continues unaffected)
- Server restarts cleanly on app relaunch

## Menu Bar

### Implementation

- SwiftUI `MenuBarExtra` with AgentCh icon
- Standard macOS menu dropdown

### Menu Items

- **Active Sessions** — list with labels and status indicators
- Separator
- **Hooks: [status]** — shows current state (Installed & Enabled / Installed & Disabled / Not Installed)
- Install / Uninstall button
- Enable / Disable button
- Separator
- **Settings** — opens settings window
- **Quit AgentCh**

### Settings Window

- Launch at login toggle (`SMAppService`)
- HTTP port number
- Reset pill position to default
- Reinstall hooks button

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI + AppKit hybrid
- **Window management:** Custom `NSPanel` subclass
- **HTTP server:** `NWListener` (Network framework)
- **Persistence:** `UserDefaults` for pill position and settings
- **Hook config:** Direct JSON read/write of `~/.claude/settings.json`
- **Launch at login:** `SMAppService`
- **Target:** macOS 26+ (required for liquid glass API)

## Project Structure

```
AgentCh/
├── AgentChApp.swift              # App entry, MenuBarExtra, app delegate
├── Models/
│   ├── Session.swift             # Session, AgentType, SessionStatus
│   └── SessionManager.swift      # ObservableObject managing all sessions
├── Views/
│   ├── PillGroupView.swift       # Compact + expanded pill group
│   ├── MascotView.swift          # Animated mascot per agent type
│   └── SettingsView.swift        # Settings window
├── Window/
│   ├── AgentChPanel.swift        # NSPanel subclass
│   └── PillHostingView.swift     # NSHostingView with hitTest override
├── Server/
│   └── EventServer.swift         # NWListener HTTP server
├── Hooks/
│   └── HookManager.swift         # Install/uninstall/enable/disable hooks
├── Menu/
│   └── MenuBarView.swift         # MenuBarExtra content
└── Assets/
    └── Mascots/                  # Claude + future agent icons
```
