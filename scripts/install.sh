#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"

echo "=== Agent Island Installer ==="
echo ""

# Step 1: Build the Swift helper
echo "[1/3] Building..."
"$SCRIPT_DIR/build.sh"

# Step 2: Copy the bridge script
echo "[2/3] Installing scripts..."
mkdir -p "$INSTALL_DIR/scripts"
cp "$SCRIPT_DIR/island.sh" "$INSTALL_DIR/scripts/island.sh"
chmod +x "$INSTALL_DIR/scripts/island.sh"

# Step 3: Install agent hooks
echo "[3/3] Installing hooks..."
echo ""

installed_any=false

# --- Claude Code ---
if command -v claude &>/dev/null; then
    CLAUDE_HOOKS="$HOME/.claude/hooks.json"
    mkdir -p "$HOME/.claude"

    if [ ! -f "$CLAUDE_HOOKS" ]; then
        cp "$PROJECT_DIR/hooks/claude-code/hooks.json" "$CLAUDE_HOOKS"
        echo "  Claude Code: hooks installed to $CLAUDE_HOOKS"
    else
        # Merge hooks using Python
        python3 -c "
import json, sys

with open('$CLAUDE_HOOKS') as f:
    existing = json.load(f)

with open('$PROJECT_DIR/hooks/claude-code/hooks.json') as f:
    island = json.load(f)

existing_hooks = existing.get('hooks', {})
island_hooks = island.get('hooks', {})

for event, entries in island_hooks.items():
    if event not in existing_hooks:
        existing_hooks[event] = entries
    else:
        # Skip if agent-island hooks already present
        existing_cmds = [h.get('command','') for entry in existing_hooks[event] for h in entry.get('hooks',[])]
        if any('island.sh' in c for c in existing_cmds):
            continue
        existing_hooks[event].extend(entries)

existing['hooks'] = existing_hooks
with open('$CLAUDE_HOOKS', 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
"
        echo "  Claude Code: hooks merged into $CLAUDE_HOOKS"
    fi
    installed_any=true
fi

# --- Codex ---
if command -v codex &>/dev/null; then
    CODEX_CONFIG="$HOME/.codex/config.toml"
    if [ -f "$CODEX_CONFIG" ] && grep -q "notify" "$CODEX_CONFIG" 2>/dev/null; then
        echo "  Codex: notify already configured in $CODEX_CONFIG"
    else
        mkdir -p "$HOME/.codex"
        echo "" >> "$CODEX_CONFIG"
        echo "notify = [\"python3\", \"$PROJECT_DIR/hooks/codex/notify.py\"]" >> "$CODEX_CONFIG"
        echo "  Codex: notify hook added to $CODEX_CONFIG"
    fi
    installed_any=true
fi

# --- OpenCode ---
if command -v opencode &>/dev/null; then
    OPENCODE_DIR="$HOME/.opencode/plugins"
    mkdir -p "$OPENCODE_DIR"
    ln -sf "$PROJECT_DIR/hooks/opencode/agent-island-plugin.js" "$OPENCODE_DIR/agent-island-plugin.js"
    echo "  OpenCode: plugin linked to $OPENCODE_DIR/"
    installed_any=true
fi

if [ "$installed_any" = false ]; then
    echo "  No supported agents detected (claude, codex, opencode)."
    echo "  Install one first, then re-run this script."
fi

echo ""
echo "================================================"
echo "  Installed to: $INSTALL_DIR"
echo "================================================"
echo ""
echo "Quick test:"
echo "  $INSTALL_DIR/scripts/island.sh start"
echo "  $INSTALL_DIR/scripts/island.sh prompt 'Your turn' 'Test' \$\$"
echo "  $INSTALL_DIR/scripts/island.sh stop"
