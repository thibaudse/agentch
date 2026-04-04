#!/bin/bash
set -e

REPO="thibaudse/agentch"
APP_NAME="AgentCh"
INSTALL_DIR="/Applications"

echo "Installing $APP_NAME..."

# Get latest release URL
DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*$APP_NAME.app.zip" \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "No release found. Building from source..."

    # Check for xcodegen
    if ! command -v xcodegen &> /dev/null; then
        echo "Installing xcodegen..."
        brew install xcodegen
    fi

    TMPDIR=$(mktemp -d)
    git clone --depth 1 "https://github.com/$REPO.git" "$TMPDIR/agentch"
    cd "$TMPDIR/agentch"
    make install
    rm -rf "$TMPDIR"
else
    # Download and install .app
    TMPDIR=$(mktemp -d)
    curl -sL "$DOWNLOAD_URL" -o "$TMPDIR/$APP_NAME.app.zip"
    unzip -q "$TMPDIR/$APP_NAME.app.zip" -d "$TMPDIR"
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$TMPDIR/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"
    rm -rf "$TMPDIR"
fi

echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Open AgentCh from Applications or Spotlight."
echo "Enable 'Launch at Login' in the app's settings."
