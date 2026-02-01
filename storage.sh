#!/bin/bash

# ========================================
# Secrets Storage Module
# ========================================
# Handles JSON storage for secrets
# Usage: source libs/omni-secrets/storage.sh

# Get path to secrets JSON file
get_secrets_file() {
    local config_dir=$(get_secrets_config_directory)
    echo "$config_dir/.secrets.json"
}

# Ensure secrets file exists
ensure_secrets_file() {
    local secrets_file=$(get_secrets_file)
    if [ ! -f "$secrets_file" ]; then
        echo "[]" > "$secrets_file"
    fi
}

# Load secrets into array
# Parameters: array_name_ref
# Usage: load_secrets secrets_array
load_secrets() {
    local -n result_array=$1
    result_array=()

    local secrets_file=$(get_secrets_file)
    if [ ! -f "$secrets_file" ]; then
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    while IFS= read -r line; do
        [ -n "$line" ] && result_array+=("$line")
    done < <(jq -r '.[] | "\(.id // ""):\(.privateKey):\(.publicKey):\(.encryptedPassphrase)"' "$secrets_file" 2>/dev/null)
}

# Save a new secret
# Parameters: name, private_key_path, public_key_path, encrypted_passphrase_path
save_secret() {
    local name="$1"
    local private_key="$2"
    local public_key="$3"
    local encrypted_passphrase="$4"

    ensure_secrets_file
    local secrets_file=$(get_secrets_file)

    # Generate UUID for this secret
    local id=$(uuidgen)

    local temp_file=$(mktemp)
    if jq --arg id "$id" \
          --arg name "$name" \
          --arg privateKey "$private_key" \
          --arg publicKey "$public_key" \
          --arg encryptedPassphrase "$encrypted_passphrase" \
          '. += [{"id": $id, "name": $name, "privateKey": $privateKey, "publicKey": $publicKey, "encryptedPassphrase": $encryptedPassphrase}]' \
          "$secrets_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$secrets_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Delete a secret by index (0-based)
# Parameters: index
delete_secret() {
    local index="$1"

    local secrets_file=$(get_secrets_file)
    if [ ! -f "$secrets_file" ]; then
        return 1
    fi

    local temp_file=$(mktemp)
    if jq --argjson idx "$index" 'del(.[$idx])' "$secrets_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$secrets_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}
