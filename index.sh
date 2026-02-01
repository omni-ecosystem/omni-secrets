#!/bin/bash

# ========================================
# Secrets Module Index
# ========================================
# Main entry point for all secrets modules
# REQUIRED: --data-dir=<path> must be provided
# Usage: source libs/omni-secrets/index.sh --data-dir=/path/to/data

# Get the directory where this script is located
SECRETS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Parse --data-dir argument
OMNI_SECRETS_DATA_DIR="${1#--data-dir=}"

# Enforce --data-dir requirement
if [[ -z "$OMNI_SECRETS_DATA_DIR" ]]; then
    echo "ERROR: omni-secrets requires --data-dir argument" >&2
    echo "Usage: source omni-secrets/index.sh --data-dir=/path/to/data" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  source omni-secrets/index.sh --data-dir=\$HOME/.local/share/omni-secrets" >&2
    return 1 2>/dev/null || exit 1
fi

# Verify data directory exists
if [[ ! -d "$OMNI_SECRETS_DATA_DIR" ]]; then
    echo "ERROR: Data directory does not exist: $OMNI_SECRETS_DATA_DIR" >&2
    echo "Please create it first: mkdir -p $OMNI_SECRETS_DATA_DIR" >&2
    return 1 2>/dev/null || exit 1
fi

# Config directory for omni-secrets
get_secrets_config_directory() {
    echo "$OMNI_SECRETS_DATA_DIR"
}

# Verify dependencies exist
if [[ ! -f "$HOME/.omni-ecosystem/omni-navigator/index.sh" ]]; then
    echo "ERROR: omni-navigator not found" >&2
    echo "Please run the installer script" >&2
    return 1 2>/dev/null || exit 1
fi

if [[ ! -f "$HOME/.omni-ecosystem/omni-ui-kit/index.sh" ]]; then
    echo "ERROR: omni-ui-kit not found" >&2
    echo "Please run the installer script" >&2
    return 1 2>/dev/null || exit 1
fi

# Source omni-deps (navigator and UI kit)
source "$HOME/.omni-ecosystem/omni-navigator/index.sh"
source "$HOME/.omni-ecosystem/omni-ui-kit/index.sh"

# Import all secrets modules in dependency order
source "$SECRETS_DIR/storage.sh"           # JSON storage functions
source "$SECRETS_DIR/vaults/storage.sh"    # Vaults JSON storage functions
source "$SECRETS_DIR/vaults/ops.sh"        # Vault mount/unmount/init
source "$SECRETS_DIR/vaults/add.sh"        # Vault add functionality
source "$SECRETS_DIR/components.sh"        # Display components
source "$SECRETS_DIR/add.sh"               # Add secret functionality
source "$SECRETS_DIR/menu.sh"              # Main menu and entry point
