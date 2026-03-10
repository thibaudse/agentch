#!/bin/bash
# build.sh - Compile the AgentIsland Swift helper
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"

echo "Building AgentIsland..."

mkdir -p "$INSTALL_DIR"

swiftc \
    -O \
    -whole-module-optimization \
    -framework AppKit \
    -framework SwiftUI \
    -o "$INSTALL_DIR/AgentIsland" \
    "$PROJECT_DIR/swift/AgentIsland.swift"

echo "Built successfully: $INSTALL_DIR/AgentIsland"
echo ""
echo "To test: $INSTALL_DIR/AgentIsland &"
echo "Then:    $SCRIPT_DIR/island.sh show 'Hello World' 'test'"
