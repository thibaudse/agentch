# 02 — Runtime Architecture

## Entry And Lifecycle

- `AgentIslandRunner.run()` starts `NSApplication`.
- `AppDelegate` receives decoded socket commands and routes to `IslandPanelController`.

## Transport

- Unix socket path: `/tmp/agent-island.sock`
- Server: `Sources/AgentIslandApp/Infrastructure/UnixSocketServer.swift`
- Protocol: one JSON command per line.

## Core Controller

`IslandPanelController` owns:

- panel creation and visibility
- prompt state wiring (`IslandViewModel`)
- response pipe writes
- process monitoring and auto-dismiss
- session queue + session-scoped dismiss

## Window Model

- Borderless non-activating panel.
- Window stays fixed to screen frame to avoid resize jitter during notch animation.
- Mouse events are enabled only in island hit frame; pass-through elsewhere.

## Display Detection

- `NotchGeometry.detect()` resolves the main display via `CGMainDisplayID()`.
- If no hardware notch metrics are available, fallback notch geometry is used on main display.

## View Stack

- `IslandView` renders shell, header controls, content region, and input controls.
- `IslandViewModel` carries mode-specific state:
  - notification
  - interactive prompt
  - permission request
  - elicitation question

## State Channels

- interactive response pipe: `responsePipe`
- permission/elicitation response pipe: `permissionResponsePipe`
- active session identity: `activeSessionID`
