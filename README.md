# agentch

A floating pill for macOS that shows your active AI agent sessions.

See at a glance which sessions are working, waiting for input, or need attention — and jump to any session with one click.

Supports **Claude Code** and **OpenAI Codex**.

## Install

### Download

Grab the latest [AgentCh.dmg](https://github.com/thibaudse/agentch/releases/latest) — open it and drag AgentCh to Applications.

If macOS says the app is "damaged or incomplete", remove the quarantine flag:

```bash
xattr -cr /Applications/AgentCh.app
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

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Usage

Open **AgentCh** from Applications or Spotlight. On first launch, it auto-installs hooks for both Claude Code and Codex and starts listening for sessions.

**Launch at Login:** enable in the AgentCh settings (menu bar icon → Settings).

### Codex setup

Codex hooks are experimental and need to be enabled:

```bash
codex features enable codex_hooks
```

Then start a new Codex session — it should appear in the pill.

### Manage hooks

Use the menu bar to install/uninstall hooks per agent, or:

- **Install all:** automatically done on first launch
- **Manage:** menu bar icon → Settings → Hooks

## Requirements

- macOS 26+ (Tahoe)
- Claude Code and/or OpenAI Codex

## License

MIT
