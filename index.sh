#!/bin/bash

# ========================================
# Secrets Module Index
# ========================================
# Main entry point for all secrets modules
# This file imports and makes available all secrets functions
# Usage: source libs/omni-secrets/index.sh

# Get the directory where this script is located
SECRETS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Config directory for omni-secrets — no dependency on host app
get_secrets_config_directory() {
    local dir
    if [[ "$SECRETS_DIR" == *"/usr/lib/"* ]]; then
        dir="$HOME/.config/omni-secrets"
    else
        dir="$SECRETS_DIR/config"
    fi
    mkdir -p "$dir" 2>/dev/null
    echo "$dir"
}

# Source omni-deps (navigator and UI kit)
source "$HOME/.omni-ecosystem/omni-navigator/index.sh"
source "$HOME/.omni-ecosystem/omni-ui-kit/index.sh"

# Import all secrets modules in dependency order
source "$SECRETS_DIR/storage.sh"           # JSON storage functions
source "$SECRETS_DIR/vaults/storage.sh"    # Vaults JSON storage functions
source "$SECRETS_DIR/vaults/ops.sh"        # Vault mount/unmount/init
source "$SECRETS_DIR/vaults/add.sh"        # Vault add functionality
source "$SECRETS_DIR/components.sh"        # UI components
source "$SECRETS_DIR/add.sh"               # Add secret functionality
source "$SECRETS_DIR/menu.sh"              # Main menu and entry point
