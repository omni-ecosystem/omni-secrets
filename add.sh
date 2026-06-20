#!/bin/bash

# ========================================
# Secrets Add Module
# ========================================
# Handles adding new secrets
# Usage: source libs/omni-secrets/add.sh

# Navigator-based add secret flow
# Returns: 0 on success, 1 on cancel
show_add_secret_flow() {
    # Step 1: Select private key
    show_interactive_browser "files" "$HOME" "/home" "Select: Private Key" "true"

    if [ ${#MARKED_FILES[@]} -eq 0 ]; then
        return 1
    fi

    local private_key_path="${MARKED_FILES[0]}"
    local private_key_dir=$(dirname "$private_key_path")
    local private_key_name=$(basename "$private_key_path")

    # Step 2: Select public key
    show_interactive_browser "files" "$private_key_dir" "/home" "Select: Public Key" "true"

    if [ ${#MARKED_FILES[@]} -eq 0 ]; then
        return 1
    fi

    local public_key_path="${MARKED_FILES[0]}"

    # Step 3: Select encrypted passphrase
    show_interactive_browser "files" "$private_key_dir" "/home" "Select: Encrypted Passphrase" "true"

    if [ ${#MARKED_FILES[@]} -eq 0 ]; then
        return 1
    fi

    local encrypted_passphrase_path="${MARKED_FILES[0]}"

    # Step 4: Save the secret
    local secret_name="$private_key_name"
    save_secret "$secret_name" "$private_key_path" "$public_key_path" "$encrypted_passphrase_path"

    clear
    print_header "ADD SECRET"
    echo ""
    echo -e "${BRIGHT_GREEN}✓${NC} Secret added successfully!"
    echo ""
    echo -e "${DIM}Private key:${NC} $(basename "$private_key_path")"
    echo -e "${DIM}Public key:${NC} $(basename "$public_key_path")"
    echo -e "${DIM}Passphrase:${NC} $(basename "$encrypted_passphrase_path")"
    echo ""
    wait_for_enter

    return 0
}

