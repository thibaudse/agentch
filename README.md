# agentch

A floating glass pill for macOS that shows your active AI agent sessions. See at a glance which Claude Code sessions are working, waiting for input, or need attention — and jump to any session with one click.

## Features

- **Floating pill overlay** — always visible, click-through, draggable anywhere
- **Session tracking** — detects Claude Code sessions via hooks
- **Status indicators** — thinking (green), waiting for input (orange), idle (gray)
- **Jump to session** — click to switch to the right terminal tab
- **Auto-expand** — pill expands when sessions need attention
- **Smart positioning** — expands away from screen edges
- **Clawd mascot** — pixel-art Claude character with animated eyes

## Install

### Homebrew (recommended)

```bash
brew install thibaudse/tap/agentch
brew services start agentch
```

### From source

```bash
git clone https://github.com/thibaudse/agentch.git
cd agentch
make install
```

### Download binary

Grab the latest release from [GitHub Releases](https://github.com/thibaudse/agentch/releases).

```bash
curl -L https://github.com/thibaudse/agentch/releases/latest/download/agentch-macos-arm64.tar.gz | tar xz
sudo mv agentch /usr/local/bin/
```

## Usage

```bash
# Start agentch
agentch

# Or auto-start on login
make launchd
```

On first launch, agentch will:
1. Install Claude Code hooks in `~/.claude/settings.json`
2. Request Accessibility permission (needed for tab switching)
3. Start listening for session events on `localhost:27182`

### Menu bar

Click the menu bar icon to:
- See active sessions and their status
- Jump to any session's terminal
- Position the pill (9 snap positions)
- Switch display
- Install/uninstall hooks
- Access settings

### Pill interactions

- **Hover** — expand to see session details
- **Drag** — reposition anywhere on screen
- **Jump button** — click the arrow to switch to that terminal tab
- **Auto-peek** — pill expands briefly on status changes

## How it works

agentch uses [Claude Code hooks](https://code.claude.com/docs/en/hooks) to receive events:

1. A hook script (`~/.agentch/hook.sh`) runs on Claude events
2. It POSTs session data to a local HTTP server (port 27182)
3. The pill UI updates in real-time via SwiftUI

### Supported hooks

| Hook | Status |
|------|--------|
| `SessionStart` | Session appears |
| `SessionEnd` | Session removed |
| `UserPromptSubmit` | Thinking (user sent message) |
| `PreToolUse` | Thinking (tool about to run) |
| `PostToolUse` | Thinking (tool finished) |
| `PermissionRequest` | Waiting (needs approval) |
| `Stop` | Waiting (Claude finished) |

### Terminal support

Jump-to-tab works with any terminal that supports:
- ANSI OSC 2 title escape (all terminals)
- macOS Accessibility AXTabGroup (native apps)

Tested with: **Ghostty**, **Terminal.app**, **iTerm2**, **Warp**, **Kitty**

## Requirements

- macOS 26+ (Tahoe) — for liquid glass effects
- Accessibility permission — for tab switching
- Claude Code — with hooks enabled

## Uninstall

```bash
# If installed via Homebrew
brew services stop agentch
brew uninstall agentch

# If installed from source
make uninstall
```

This removes the binary, hooks from `~/.claude/settings.json`, and the launch agent.

## License

MIT
