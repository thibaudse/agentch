#!/bin/bash
set -e

REPO="thibaudse/agentch"
INSTALL_DIR="/usr/local/bin"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ASSET="agentch-macos-arm64.tar.gz"
elif [ "$ARCH" = "x86_64" ]; then
    ASSET="agentch-macos-x86_64.tar.gz"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "Installing agentch..."

# Get latest release URL
DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*$ASSET" \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "No release found. Building from source..."
    TMPDIR=$(mktemp -d)
    git clone --depth 1 "https://github.com/$REPO.git" "$TMPDIR/agentch"
    cd "$TMPDIR/agentch"
    swift build -c release
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp .build/release/agentch "$INSTALL_DIR/agentch"
    rm -rf "$TMPDIR"
else
    # Download and install binary
    TMPDIR=$(mktemp -d)
    curl -sL "$DOWNLOAD_URL" | tar xz -C "$TMPDIR"
    sudo mkdir -p "$INSTALL_DIR"
    sudo mv "$TMPDIR/agentch" "$INSTALL_DIR/agentch"
    rm -rf "$TMPDIR"
fi

echo "Installed to $INSTALL_DIR/agentch"
echo ""
echo "Run 'agentch' to start."
echo "Run 'agentch --launchd' to auto-start on login."
