#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"
BINARY_NAME="AgentIsland"

echo "Building ${BINARY_NAME} with SwiftPM..."

swift build --configuration release --product "$BINARY_NAME" --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build --configuration release --product "$BINARY_NAME" --package-path "$PROJECT_DIR" --show-bin-path)"

mkdir -p "$INSTALL_DIR/scripts/hooks"
cp "$BIN_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Copy scripts
cp "$SCRIPT_DIR/island.sh" "$INSTALL_DIR/scripts/island.sh"
chmod +x "$INSTALL_DIR/scripts/island.sh"
cp "$SCRIPT_DIR/hooks/claude-show.sh" "$INSTALL_DIR/scripts/hooks/claude-show.sh"
chmod +x "$INSTALL_DIR/scripts/hooks/claude-show.sh"
cp "$SCRIPT_DIR/hooks/claude-permission.sh" "$INSTALL_DIR/scripts/hooks/claude-permission.sh"
chmod +x "$INSTALL_DIR/scripts/hooks/claude-permission.sh"

echo "Built successfully: $INSTALL_DIR/$BINARY_NAME"
echo ""
echo "Quick test:"
echo "  $SCRIPT_DIR/island.sh start"
echo "  $SCRIPT_DIR/island.sh show 'Hello World' 'test'"
