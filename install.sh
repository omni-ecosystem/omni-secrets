#!/bin/bash

set -e

REPO_URL="git@github.com:nickojs/omni-secrets.git"
INSTALL_DIR="$HOME/.omni-ecosystem"
TARGET_DIR="$INSTALL_DIR/omni-secrets"
NAVIGATOR_DIR="$INSTALL_DIR/omni-navigator"
NAVIGATOR_INSTALL_URL="https://raw.githubusercontent.com/omni-ecosystem/omni-navigator/refs/heads/main/install.sh"

echo "=== Omni Secrets Installer ==="
echo ""

# Check for omni-navigator dependency
if [ ! -d "$NAVIGATOR_DIR" ]; then
    echo "⚠️  Dependency missing: omni-navigator not found"
    echo "Installing omni-navigator first (this will also install omni-ui-kit)..."
    echo ""

    # Download and run omni-navigator install script
    curl -fsSL "$NAVIGATOR_INSTALL_URL" | bash

    echo ""
    echo "Continuing with omni-secrets installation..."
    echo ""
fi

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if omni-secrets already exists
if [ -d "$TARGET_DIR" ]; then
    echo "omni-secrets already exists at $TARGET_DIR"
    echo "Updating existing installation..."

    cd "$TARGET_DIR"

    # Check if it's a git repository
    if [ -d ".git" ]; then
        echo "Fetching latest changes..."
        git fetch origin

        echo "Pulling updates..."
        git pull origin main || git pull origin master

        echo ""
        echo "✓ Update complete!"
    else
        echo "ERROR: $TARGET_DIR exists but is not a git repository"
        exit 1
    fi
else
    echo "Installing omni-secrets to $TARGET_DIR..."

    cd "$INSTALL_DIR"
    git clone "$REPO_URL"

    echo ""
    echo "✓ Installation complete!"
fi

echo ""
echo "omni-secrets is located at: $TARGET_DIR"
echo ""
echo "IMPORTANT: omni-secrets requires --data-dir when sourced:"
echo "  source ~/.omni-ecosystem/omni-secrets/index.sh --data-dir=/path/to/data"
echo ""
echo "Example:"
echo "  source ~/.omni-ecosystem/omni-secrets/index.sh --data-dir=\$HOME/.local/share/omni-secrets"
