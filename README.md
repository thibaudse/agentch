# agentch

A floating glass pill for macOS that shows your active AI agent sessions.

See at a glance which sessions are working, waiting for input, or need attention — and jump to any session with one click.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/thibaudse/agentch/main/install.sh | bash
```

## Usage

```bash
agentch
```

On first launch, agentch auto-installs Claude Code hooks and starts listening for sessions.

**Auto-start on login:**
```bash
make launchd
```

## Requirements

- macOS 26+ (Tahoe)
- Claude Code with hooks enabled

## License

MIT
