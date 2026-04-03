# agentch

A floating pill for macOS that shows your active AI agent sessions.

See at a glance which sessions are working, waiting for input, or need attention — and jump to any session with one click.

Supports **Claude Code** and **OpenAI Codex**.

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

On first launch, agentch auto-installs hooks for both Claude Code and Codex and starts listening for sessions.

**Auto-start on login:**
```bash
agentch --launchd
```

### Codex setup

Codex hooks are experimental and need to be enabled:

```bash
codex features enable codex_hooks
```

Then start a new Codex session — it should appear in the pill.

### Manage hooks

Use the menu bar to install/uninstall hooks per agent, or:

- **Install all:** automatically done on launch
- **Uninstall:** via menu bar → Hooks → Uninstall All

## Requirements

- macOS 26+ (Tahoe)
- Claude Code and/or OpenAI Codex

## License

MIT
