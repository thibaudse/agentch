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

## Validation Commands

```bash
swift build
bash -n scripts/island.sh
bash -n scripts/hooks/claude-show.sh
bash -n scripts/hooks/claude-permission.sh
bash -n scripts/hooks/claude-dismiss.sh
```
