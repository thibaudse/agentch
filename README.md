# agentch

A floating glass pill for macOS that shows your active AI agent sessions.

See at a glance which sessions are working, waiting for input, or need attention — and jump to any session with one click.

## Install

```bash
git clone https://github.com/thibaudse/agentch.git
cd agentch
make install
```

Or download the binary from [Releases](https://github.com/thibaudse/agentch/releases).

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
