# agentch

A floating glass pill for macOS that shows your active AI agent sessions.

See at a glance which sessions are working, waiting for input, or need attention — and jump to any session with one click.

## Install

### Homebrew

```bash
brew tap thibaudse/agentch https://github.com/thibaudse/agentch
brew install --HEAD agentch
brew services start agentch
```

### Script

```bash
curl -fsSL https://raw.githubusercontent.com/thibaudse/agentch/main/install.sh | bash
```

### From source

```bash
git clone https://github.com/thibaudse/agentch.git
cd agentch
make install
```

## Usage

```bash
agentch
```

On first launch, agentch auto-installs Claude Code hooks and starts listening for sessions.

## Requirements

- macOS 26+ (Tahoe)
- Claude Code with hooks enabled

## License

MIT
