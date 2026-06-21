#!/bin/bash

# ========================================
# Vaults Storage Module
# ========================================
# Handles JSON storage for vaults
# Usage: source libs/omni-secrets/vaults/storage.sh

# Get path to vaults JSON file
get_vaults_file() {
    local config_dir=$(get_secrets_config_directory)
    echo "$config_dir/.vaults.json"
}

# Ensure vaults file exists
ensure_vaults_file() {
    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        echo "[]" > "$vaults_file"
    fi
}

# Load vaults into array
# Parameters: array_name_ref
# Returns: name:vaultLocation:cipherDir:mountPoint:secretId
#   vaultLocation is empty string for legacy vaults that predate this field
load_vaults() {
    local -n result_array=$1
    result_array=()

    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    while IFS= read -r line; do
        [ -n "$line" ] && result_array+=("$line")
    done < <(jq -r '.[] | "\(.name):\(.vaultLocation // ""):\(.cipherDir):\(.mountPoint):\(.secretId)"' "$vaults_file" 2>/dev/null)
}

# Save a new vault
# Parameters: name, vault_location, cipher_dir, mount_point, secret_id
save_vault() {
    local name="$1"
    local vault_location="$2"
    local cipher_dir="$3"
    local mount_point="$4"
    local secret_id="$5"

    ensure_vaults_file
    local vaults_file=$(get_vaults_file)

    local temp_file=$(mktemp)
    if jq --arg name "$name" \
          --arg vaultLocation "$vault_location" \
          --arg cipherDir "$cipher_dir" \
          --arg mountPoint "$mount_point" \
          --arg secretId "$secret_id" \
          '. += [{"name": $name, "vaultLocation": $vaultLocation, "cipherDir": $cipherDir, "mountPoint": $mountPoint, "secretId": $secretId}]' \
          "$vaults_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$vaults_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Delete a vault by index (0-based)
# Parameters: index
delete_vault() {
    local index="$1"

    # Get vault info before deletion
    local -a vaults=()
    load_vaults vaults

    if [ "$index" -ge "${#vaults[@]}" ]; then
        return 1
    fi

    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        return 1
    fi

    local temp_file=$(mktemp)
    if jq --argjson idx "$index" 'del(.[$idx])' "$vaults_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$vaults_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Update vault's secret assignment
# Parameters: vault_index (0-based), new_secret_id
# Returns: 0 on success, 1 on failure
update_vault_secret() {
    local vault_index="$1"
    local new_secret_id="$2"

    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        return 1
    fi

    # Verify the new secret exists
    if ! get_secret_by_id "$new_secret_id" >/dev/null 2>&1; then
        echo "Secret ID not found: $new_secret_id"
        return 1
    fi

    local temp_file=$(mktemp)
    if jq --argjson idx "$vault_index" \
          --arg secretId "$new_secret_id" \
          '.[$idx].secretId = $secretId' \
          "$vaults_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$vaults_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Update vault's cipher directory
# Parameters: vault_index (0-based), new_cipher_dir
# Returns: 0 on success, 1 on failure
update_vault_cipher_dir() {
    local vault_index="$1"
    local new_cipher_dir="$2"

    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        return 1
    fi

    local temp_file=$(mktemp)
    if jq --argjson idx "$vault_index" \
          --arg cipherDir "$new_cipher_dir" \
          '.[$idx].cipherDir = $cipherDir' \
          "$vaults_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$vaults_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Update vault's mount point
# Parameters: vault_index (0-based), new_mount_point
# Returns: 0 on success, 1 on failure
update_vault_mount_point() {
    local vault_index="$1"
    local new_mount_point="$2"

    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        return 1
    fi

    local temp_file=$(mktemp)
    if jq --argjson idx "$vault_index" \
          --arg mountPoint "$new_mount_point" \
          '.[$idx].mountPoint = $mountPoint' \
          "$vaults_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$vaults_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Update vault's location (atomically sets vaultLocation, cipherDir, and mountPoint)
# Parameters: vault_index (0-based), new_vault_location
# Returns: 0 on success, 1 on failure
update_vault_location() {
    local vault_index="$1"
    local new_location="$2"
    local new_cipher_dir="$new_location/cipher"
    local new_mount_point="$new_location/mount"

    local vaults_file=$(get_vaults_file)
    if [ ! -f "$vaults_file" ]; then
        return 1
    fi

    local temp_file=$(mktemp)
    if jq --argjson idx "$vault_index" \
          --arg vaultLocation "$new_location" \
          --arg cipherDir "$new_cipher_dir" \
          --arg mountPoint "$new_mount_point" \
          '.[$idx].vaultLocation = $vaultLocation | .[$idx].cipherDir = $cipherDir | .[$idx].mountPoint = $mountPoint' \
          "$vaults_file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$vaults_file"
        return 0
    fi
    rm -f "$temp_file"
    return 1
}

# Get secret by UUID
# Parameters: secret_id
# Returns: id:privateKey:publicKey:encryptedPassphrase (echoes to stdout)
get_secret_by_id() {
    local secret_id="$1"

    local secrets_file=$(get_secrets_file)
    if [ ! -f "$secrets_file" ]; then
        return 1
    fi

    local result
    result=$(jq -r --arg id "$secret_id" '.[] | select(.id == $id) | "\(.id):\(.privateKey):\(.publicKey):\(.encryptedPassphrase)"' "$secrets_file" 2>/dev/null)

    if [ -n "$result" ]; then
        echo "$result"
        return 0
    fi
    return 1
}

# Get vault mount status
# Parameters: mount_point
# Returns: 0 if mounted, 1 if not
get_vault_status() {
    local mount_point="$1"

    if mountpoint -q "$mount_point" 2>/dev/null; then
        return 0
    fi
    return 1
}
