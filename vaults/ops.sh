#!/bin/bash

# ========================================
# Vault Operations Module
# ========================================
# Mount, unmount, and init operations for gocryptfs vaults
# Usage: source libs/omni-secrets/vaults/ops.sh

# Mount a vault
# Parameters: vault_index (0-based)
# Returns: 0 on success, 1 on failure
mount_vault() {
    local vault_index="$1"

    local -a vaults=()
    load_vaults vaults

    if [ "$vault_index" -lt 0 ] || [ "$vault_index" -ge "${#vaults[@]}" ]; then
        echo "Invalid vault index"
        return 1
    fi

    local vault_info="${vaults[$vault_index]}"
    IFS=':' read -r name cipher_dir mount_point secret_id <<< "$vault_info"

    # Check if already mounted
    if get_vault_status "$mount_point"; then
        echo "Vault '$name' is already mounted"
        return 1
    fi

    # Get secret data
    local secret_data
    if ! secret_data=$(get_secret_by_id "$secret_id"); then
        echo "Secret not found for vault '$name'"
        echo ""
        read -p "Reassign a secret to this vault? (y/n): " -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Load available secrets
            local -a secrets=()
            load_secrets secrets

            if [ ${#secrets[@]} -eq 0 ]; then
                echo "No secrets available"
                return 1
            fi

            # Get user selection (referencing list already on screen)
            echo -n "Which secret? "
            local secret_num
            read -r secret_num

            # Validate input
            if ! [[ "$secret_num" =~ ^[0-9]+$ ]] || [ "$secret_num" -lt 1 ] || [ "$secret_num" -gt "${#secrets[@]}" ]; then
                echo "Invalid selection"
                return 1
            fi

            # Extract selected secret ID
            local secret_index=$((secret_num - 1))
            local selected_secret="${secrets[$secret_index]}"
            IFS=':' read -r new_secret_id _ _ _ <<< "$selected_secret"

            # Update vault configuration
            if update_vault_secret "$vault_index" "$new_secret_id"; then
                echo "Secret reassigned successfully"
                # Update the local secret_id variable and retry
                secret_id="$new_secret_id"
                if ! secret_data=$(get_secret_by_id "$secret_id"); then
                    echo "Failed to get reassigned secret"
                    return 1
                fi
            else
                echo "Failed to update vault configuration"
                return 1
            fi
        else
            echo "Secret reassignment cancelled"
            return 1
        fi
    fi

    IFS=':' read -r _ private_key _ encrypted_passphrase <<< "$secret_data"

    # Check if cipher directory exists
    if [ ! -d "$cipher_dir" ]; then
        echo "Vault directory '$cipher_dir' does not exist for vault '$name'"
        echo "The encrypted vault folder may have been deleted or moved"
        echo ""
        read -p "Recreate empty vault at this location? (y/n): " -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Recreating vault '$name'..."

            # Call init_vault to create fresh gocryptfs structure
            if init_vault "$cipher_dir" "$secret_id"; then
                echo "Vault structure recreated successfully"
                echo "Attempting to mount..."

                # Retry mount (fall through to existing mount logic below)
            else
                echo "Failed to recreate vault structure"
                return 1
            fi
        else
            echo "Vault recreation cancelled"
            return 1
        fi
    fi

    # Ensure mount point exists
    if [ ! -d "$mount_point" ]; then
        mkdir -p "$mount_point"
    fi

    # Verify passphrase can be decrypted
    local passphrase
    if ! passphrase=$(age -d -i "$private_key" "$encrypted_passphrase" 2>/dev/null); then
        echo "Failed to decrypt passphrase for vault '$name'"
        echo "The age private key may not match the encrypted passphrase file"
        echo ""
        echo "Debug info:"
        echo "  Private key: ${private_key/#$HOME/\~}"
        echo "  Encrypted passphrase: ${encrypted_passphrase/#$HOME/\~}"
        return 1
    fi

    # Mount using piped passphrase
    if echo "$passphrase" | gocryptfs -q "$cipher_dir" "$mount_point" 2>/dev/null; then
        return 0
    fi

    echo "Failed to mount vault '$name'"
    echo "The passphrase was decrypted successfully, but gocryptfs rejected it."
    echo "This vault may have been initialized with a different passphrase."
    echo ""
    echo "Debug info:"
    echo "  Cipher dir: ${cipher_dir/#$HOME/\~}"
    echo "  Mount point: ${mount_point/#$HOME/\~}"
    echo "  Secret ID: $secret_id"
    return 1
}

# Unmount a vault
# Parameters: vault_index (0-based)
# Returns: 0 on success, 1 on failure
unmount_vault() {
    local vault_index="$1"

    local -a vaults=()
    load_vaults vaults

    if [ "$vault_index" -lt 0 ] || [ "$vault_index" -ge "${#vaults[@]}" ]; then
        echo "Invalid vault index"
        return 1
    fi

    local vault_info="${vaults[$vault_index]}"
    IFS=':' read -r name _ mount_point _ <<< "$vault_info"

    # Check if mounted
    if ! get_vault_status "$mount_point"; then
        echo "Vault '$name' is not mounted"
        return 1
    fi

    # Unmount
    if fusermount -u "$mount_point"; then
        return 0
    fi

    return 1
}

# Initialize a new vault (gocryptfs -init)
# Parameters: cipher_dir, secret_id
# Returns: 0 on success, 1 on failure
init_vault() {
    local cipher_dir="$1"
    local secret_id="$2"

    # Get secret data
    local secret_data
    if ! secret_data=$(get_secret_by_id "$secret_id"); then
        echo "Secret not found"
        return 1
    fi

    IFS=':' read -r _ private_key _ encrypted_passphrase <<< "$secret_data"

    # Ensure cipher dir exists
    if [ ! -d "$cipher_dir" ]; then
        mkdir -p "$cipher_dir"
    fi

    # Check if already initialized
    if [ -f "$cipher_dir/gocryptfs.conf" ]; then
        echo "Vault already initialized at '$cipher_dir'"
        return 1
    fi

    # Initialize using piped passphrase
    if age -d -i "$private_key" "$encrypted_passphrase" 2>/dev/null | gocryptfs -init -q "$cipher_dir" 2>/dev/null; then
        return 0
    fi

    echo "Failed to initialize vault"
    return 1
}

# Reassign secret to a vault (interactive)
# Parameters: vault_index (0-based)
# Returns: 0 on success, 1 on failure
reassign_vault_secret() {
    local vault_index="$1"

    local -a vaults=()
    load_vaults vaults

    if [ "$vault_index" -lt 0 ] || [ "$vault_index" -ge "${#vaults[@]}" ]; then
        echo "Invalid vault index"
        return 1
    fi

    local vault_info="${vaults[$vault_index]}"
    IFS=':' read -r name _ _ _ <<< "$vault_info"

    # Load available secrets
    local -a secrets=()
    load_secrets secrets

    if [ ${#secrets[@]} -eq 0 ]; then
        echo "No secrets available"
        return 1
    fi

    # Get user selection (referencing list already on screen)
    echo -n "Which secret for vault '$name'? "
    local secret_num
    read -r secret_num

    # Validate input
    if ! [[ "$secret_num" =~ ^[0-9]+$ ]] || [ "$secret_num" -lt 1 ] || [ "$secret_num" -gt "${#secrets[@]}" ]; then
        echo "Invalid selection"
        return 1
    fi

    # Extract selected secret ID
    local secret_index=$((secret_num - 1))
    local selected_secret="${secrets[$secret_index]}"
    IFS=':' read -r new_secret_id _ _ _ <<< "$selected_secret"

    # Update vault configuration
    if update_vault_secret "$vault_index" "$new_secret_id"; then
        echo "Secret reassigned successfully"
        return 0
    else
        echo "Failed to update vault configuration"
        return 1
    fi
}
