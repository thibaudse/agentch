# agentch

`agentch` displays an animated notch-style status chip on macOS when coding agents are waiting for user input.

It includes:
- a native SwiftUI app (`AgentIsland`) that renders and animates the notch extension,
- a local Unix socket server for commands (`/tmp/agent-island.sock`),
- shell + hook integrations for Claude Code.

## Project Structure

```text
.
├── Package.swift
├── Sources/
│   └── AgentIslandApp/
│       ├── Main.swift
│       ├── AppDelegate.swift
│       ├── Config/
│       │   └── AppConfig.swift
│       ├── Domain/
│       │   └── IslandCommand.swift
│       ├── Infrastructure/
│       │   └── UnixSocketServer.swift
│       └── UI/
│           ├── IslandPanelController.swift
│           ├── IslandView.swift
│           ├── IslandViewModel.swift
│           └── NotchGeometry.swift
├── hooks/
│   └── claude-code/hooks.json
└── scripts/
    ├── build.sh
    ├── install.sh
    └── island.sh
```

## Build

```bash
./scripts/build.sh
```

This builds with SwiftPM in release mode and installs the executable to:

```text
${AGENT_ISLAND_HOME:-$HOME/.agent-island}/AgentIsland
```

## Run and Test

```bash
./scripts/island.sh start
./scripts/island.sh show "Hello World" "Claude"
./scripts/island.sh dismiss
./scripts/island.sh stop
```

## Command Protocol

The app listens on a Unix domain socket and accepts one JSON message per line:

```json
{"action":"show","message":"Waiting for input","agent":"Claude","duration":0}
{"action":"dismiss"}
{"action":"quit"}
```

## Agent Integrations

- Claude Code hooks: `hooks/claude-code/hooks.json`

Use `./scripts/install.sh` for setup instructions on your machine.

## Extending Features

Most new features should be added in one focused area:
- UI/animation tweaks: `Sources/AgentIslandApp/UI/IslandView.swift`
- behavior/state: `Sources/AgentIslandApp/UI/IslandPanelController.swift` and `Sources/AgentIslandApp/UI/IslandViewModel.swift`
- protocol changes: `Sources/AgentIslandApp/Domain/IslandCommand.swift`
- transport/server changes: `Sources/AgentIslandApp/Infrastructure/UnixSocketServer.swift`
