# 06 — Ops, Build, Debug

## Build + Install

```bash
bash scripts/build.sh
```

This compiles release binary and installs scripts/hooks to:

- `~/.agent-island/AgentIsland`
- `~/.agent-island/scripts/...`

## Daemon Control

```bash
~/.agent-island/scripts/island.sh start
~/.agent-island/scripts/island.sh stop
~/.agent-island/scripts/island.sh dismiss
```

## Logs

- daemon: `/tmp/agent-island.log`
- hooks: `/tmp/agent-island-hook.log`

## Common Failures

### Stale socket

Symptom: commands succeed silently but no notch appears.

Fix:

- `scripts/island.sh` validates socket has a listener.
- If stale socket/pid is detected, it clears and relaunches daemon.

### Wrong display

Symptom: notch appears on unexpected monitor.

Fix:

- `NotchGeometry.detect()` uses `CGMainDisplayID()` mapping to `NSScreen`.

### Hook appears stuck

Check:

- hook has valid response pipe path
- session-scoped dismiss route is configured
- hook script under `~/.agent-island/scripts/hooks/` matches repo copy

Timeout controls:

- `AGENTCH_STOP_TIMEOUT_SECS` (default `590`)
- `AGENTCH_PERMISSION_TIMEOUT_SECS` (default `110`)

Hooks dismiss the matching session notch on timeout or termination signal.

### Multiple daemons running

Symptom: inconsistent behavior after switching source/brew installs.

Fix:

- ensure a single `AgentIsland` process owns `/tmp/agent-island.sock`
- stop one runtime before starting the other

## Validation Commands

```bash
swift build
bash -n scripts/island.sh
bash -n scripts/hooks/claude-show.sh
bash -n scripts/hooks/claude-permission.sh
bash -n scripts/hooks/claude-dismiss.sh
```
