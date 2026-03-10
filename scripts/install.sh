#!/bin/bash
# install.sh - Build the helper and set up hooks for detected agents
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"

echo "=== Agent Island Installer ==="
echo ""

# Step 1: Build the Swift helper
echo "[1/3] Building Swift helper..."
"$SCRIPT_DIR/build.sh"

# Step 2: Copy the bridge script
echo "[2/3] Installing bridge script..."
mkdir -p "$INSTALL_DIR/scripts"
cp "$SCRIPT_DIR/island.sh" "$INSTALL_DIR/scripts/island.sh"
chmod +x "$INSTALL_DIR/scripts/island.sh"

# Step 3: Show setup instructions for each agent
echo "[3/3] Agent configuration"
echo ""
echo "================================================"
echo "  Agent Island installed to: $INSTALL_DIR"
echo "================================================"
echo ""

# Check for Claude Code
if command -v claude &>/dev/null; then
    echo "--- Claude Code detected ---"
    echo ""
    echo "Option A: Install as a Claude Code plugin (recommended)"
    echo "  Copy the hooks directory into your project:"
    echo "    mkdir -p .claude/plugins/agent-island/hooks"
    echo "    cp $PROJECT_DIR/hooks/claude-code/hooks.json .claude/plugins/agent-island/hooks/hooks.json"
    echo ""
    echo "Option B: Add to your user settings (~/.claude/settings.json):"
    echo "  Merge the hooks from: $PROJECT_DIR/hooks/claude-code/hooks.json"
    echo ""
fi

# Check for Codex
if command -v codex &>/dev/null; then
    echo "--- Codex CLI detected ---"
    echo ""
    echo "  Add to ~/.codex/config.toml:"
    echo "    notify = [\"python3\", \"$PROJECT_DIR/hooks/codex/notify.py\"]"
    echo ""
fi

# Check for OpenCode
if command -v opencode &>/dev/null; then
    echo "--- OpenCode detected ---"
    echo ""
    echo "  Copy or symlink the plugin:"
    echo "    mkdir -p .opencode/plugins"
    echo "    ln -sf $PROJECT_DIR/hooks/opencode/agent-island-plugin.js .opencode/plugins/agent-island-plugin.js"
    echo ""
fi

echo "--- Quick test ---"
echo ""
echo "  # Start the helper daemon:"
echo "  $INSTALL_DIR/scripts/island.sh start"
echo ""
echo "  # Show a test notification:"
echo "  $INSTALL_DIR/scripts/island.sh show 'Hello World' 'Test'"
echo ""
echo "  # Dismiss it:"
echo "  $INSTALL_DIR/scripts/island.sh dismiss"
echo ""
echo "  # Stop the daemon:"
echo "  $INSTALL_DIR/scripts/island.sh stop"
