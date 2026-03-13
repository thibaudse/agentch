# agentch

`agentch` is a notch-style macOS surface for Claude sessions.

- It currently supports **Claude only**.
- It integrates through **Claude hooks** (`Stop`, `PermissionRequest`, `UserPromptSubmit`).
- It runs as a local app (`AgentIsland`) listening on `/tmp/agent-island.sock`.

## How It Works

1. Claude triggers a hook event.
2. Hook scripts call `scripts/island.sh`.
3. `island.sh` sends a JSON command to the local socket.
4. `AgentIsland` renders the notch UI and returns responses through FIFO pipes.

## Requirements

- macOS
- Xcode Command Line Tools (`xcode-select --install`)
- Claude CLI configured on your machine

## Install (Recommended)

From repo root:

```bash
bash scripts/build.sh
```

This installs to:

- `${AGENT_ISLAND_HOME:-$HOME/.agent-island}/AgentIsland`
- `${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh`
- `${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/hooks/claude-*.sh`

### Configure Claude Hooks

`agentch` requires hooks in `~/.claude/settings.json`.

Quick merge helper (run from repo root):

```bash
python3 - <<'PY'
import json
from pathlib import Path

repo = Path.cwd()
incoming = json.loads((repo / "hooks/claude-code/hooks.json").read_text())
settings_path = Path.home() / ".claude/settings.json"
settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hooks = settings.get("hooks", {})

for event, entries in incoming.get("hooks", {}).items():
    existing = hooks.get(event, [])
    existing = [
        e for e in existing
        if not any("agent-island" in h.get("command", "") for h in e.get("hooks", []))
    ]
    hooks[event] = existing + entries

settings["hooks"] = hooks
settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(settings, indent=2) + "\n")
print(f"Updated {settings_path}")
PY
```

Restart Claude after changing hooks.

## Keep It Running

You usually do not need manual daemon management.

- `scripts/island.sh` auto-starts the daemon on demand.
- It also recovers stale socket state automatically.

Manual control:

```bash
~/.agent-island/scripts/island.sh start
~/.agent-island/scripts/island.sh stop
```

## Quick Test

```bash
~/.agent-island/scripts/island.sh prompt "Test" "Claude" 0 "" "" "" "**Claude:** Hello" "" "test-session"
```

## Logs

- Daemon: `/tmp/agent-island.log`
- Hooks: `/tmp/agent-island-hook.log`

## Project Structure

```text
.
├── hooks/claude-code/hooks.json
├── scripts/
│   ├── build.sh
│   ├── island.sh
│   └── hooks/
│       ├── claude-show.sh
│       ├── claude-permission.sh
│       └── claude-dismiss.sh
└── Sources/AgentIslandApp/
    ├── Domain/IslandCommand.swift
    ├── Infrastructure/UnixSocketServer.swift
    └── UI/
```
