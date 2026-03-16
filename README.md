# agentch

`agentch` is a notch-style macOS surface for Claude sessions.

- It currently supports **Claude only**.
- It integrates through **Claude hooks** (`Stop`, `PermissionRequest`, `UserPromptSubmit`).
- It runs as a local app (`AgentIsland`) listening on `/tmp/agent-island.sock`.

## How It Works

1. Claude triggers a hook event.
2. Hook scripts call `agentch-island` (or `scripts/island.sh` in source installs).
3. `island.sh` sends a JSON command to the local socket.
4. `AgentIsland` renders the notch UI and returns responses through FIFO pipes.

## Requirements

- macOS
- Xcode Command Line Tools (`xcode-select --install`)
- Claude CLI configured on your machine

## Install (Homebrew)

No repo clone needed:

> Requires public tap repo: `thibaudse/homebrew-agentch`

```bash
brew tap thibaudse/agentch
brew install thibaudse/agentch/agentch
agentch-install-hooks
brew services start thibaudse/agentch/agentch
```

What this does:

- installs the app + scripts
- writes Claude hook commands into `~/.claude/settings.json`
- starts `agentch` at login/restart via `brew services`

After hook changes, restart Claude.

## Update (Homebrew)

```bash
brew update
brew reinstall thibaudse/agentch/agentch
agentch-install-hooks
```

The running daemon detects version mismatches automatically — on the next Claude session, `island.sh` compares the running daemon version against the installed binary and restarts silently if they differ. No manual `brew services restart` needed.

`agentch` also checks GitHub releases once per day and shows a non-blocking notch notification when a newer version is available.

Notes:

- `agentch-install-hooks` re-applies hook commands in `~/.claude/settings.json`.
- Restart Claude after updating hooks.
- If service status is not `started`, run `brew services start thibaudse/agentch/agentch`.

## Install (From Source)

From repo root:

```bash
bash scripts/build.sh
bash scripts/install-claude-hooks.sh
```

This installs to:

- `${AGENT_ISLAND_HOME:-$HOME/.agent-island}/AgentIsland`
- `${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh`
- `${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/hooks/claude-*.sh`

Then restart Claude after changing hooks.

## Keep It Running

`agentch` should stay available automatically.

- `brew services start thibaudse/agentch/agentch` keeps it running across login/reboot.
- Hook calls still auto-start the daemon if it is not running.
- `island.sh` also recovers stale socket state and auto-restarts on version mismatch.

If you want startup check before every Claude launch, add this to `~/.zshrc`:

```bash
claude() {
  agentch-island start >/dev/null 2>&1 || true
  command claude "$@"
}
```

Manual control:

```bash
agentch-island start
agentch-island stop
```

## Quick Test

```bash
agentch-island prompt "Test" "Claude" 0 "" "" "" "**Claude:** Hello" "" "test-session"
```

## Bash Permission Preview

For `Bash` permission prompts, `description` is rendered as metadata above the preview and only command lines are shown in the code block.

Expected payload shape from hooks:

```text
Command
description: <short explanation>
$ <actual command>
  && <continued command>
```

Manual smoke test:

```bash
agentch-island permission "Bash" $'description: Test description outside code block\nCommand\n$ echo "hello"\n  && pwd' "Claude" 0 "" "[]" "bash-preview-test" "agent-island"
```

## Logs

- Daemon: `/tmp/agent-island.log`
- Hooks: `/tmp/agent-island-hook.log`

## Hook Timeout Behavior

To prevent stale notch prompts when a hook times out, hooks dismiss the session-scoped notch on timeout/signal.

Optional env vars:

- `AGENTCH_STOP_TIMEOUT_SECS` (default `590`)
- `AGENTCH_PERMISSION_TIMEOUT_SECS` (default `110`)

Example:

```bash
AGENTCH_STOP_TIMEOUT_SECS=300 AGENTCH_PERMISSION_TIMEOUT_SECS=90 claude
```

## Project Structure

```text
.
├── Formula/agentch.rb
├── hooks/claude-code/hooks.json
├── scripts/
│   ├── build.sh
│   ├── check-update.sh
│   ├── install-claude-hooks.sh
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

## Maintainer Notes (Tap)

- Formula source is `Formula/agentch.rb`.
- Formula currently tracks `main.tar.gz` and requires `sha256` refresh when source changes.
- Refresh checksum with:

```bash
curl -Ls https://github.com/thibaudse/agentch/archive/refs/heads/main.tar.gz | shasum -a 256
```
