#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"
BINARY_NAME="AgentIsland"

echo "Building ${BINARY_NAME} with SwiftPM..."

swift build --configuration release --product "$BINARY_NAME" --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build --configuration release --product "$BINARY_NAME" --package-path "$PROJECT_DIR" --show-bin-path)"

mkdir -p "$INSTALL_DIR"
cp "$BIN_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Built successfully: $INSTALL_DIR/$BINARY_NAME"
echo ""
echo "Quick test:"
echo "  $SCRIPT_DIR/island.sh start"
echo "  $SCRIPT_DIR/island.sh show 'Hello World' 'test'"
