#!/bin/bash

# ========================================
# Vault Add Module
# ========================================
# Add vault flow
# Usage: source libs/omni-secrets/vaults/add.sh

# Global variables for select_secret_interactive results
declare -g SECRET_ID_RESULT=""
declare -g PASSPHRASE_RESULT=""


# Add vault screen
# Returns: 0 on success, 1 on cancel
show_add_vault_screen() {
    local -a secrets=()
    load_secrets secrets
    local secret_count=${#secrets[@]}

    if [ "$secret_count" -eq 0 ]; then
        clear
        print_header "ADD VAULT"
        echo ""
        echo -e "${BRIGHT_RED}No secrets found${NC}"
        echo -e "${DIM}Add a secret first before creating vaults${NC}"
        echo ""
        wait_for_enter
        return 1
    fi

    printf '\033[?25h'

    # Step 1: Choose vault type
    clear
    print_header "ADD VAULT"
    echo ""
    echo -e "${BRIGHT_WHITE}What would you like to do?${NC}"
    echo ""
    echo -e "${BRIGHT_CYAN}1${NC}  New vault      ${DIM}create and initialize a vault${NC}"
    echo -e "${BRIGHT_CYAN}2${NC}  Re-register    ${DIM}restore a vault created by this tool that lost its registration${NC}"
    echo ""
    echo -e "${DIM}Press ESC to cancel${NC}"
    echo -ne "${BRIGHT_WHITE}Choice:${NC} "
    local vault_type
    read_with_esc_cancel vault_type
    local read_result=$?

    if [ $read_result -eq 2 ] || [ -z "$vault_type" ]; then
        return 1
    fi

    if [ "$vault_type" = "1" ]; then
        # NEW VAULT FLOW
        add_vault "new" "$secret_count" "${secrets[@]}"
        return $?
    elif [ "$vault_type" = "2" ]; then
        # RE-REGISTER FLOW
        add_vault "existing" "$secret_count" "${secrets[@]}"
        return $?
    else
        clear
        print_header "ERROR"
        echo ""
        echo -e "${BRIGHT_RED}Invalid choice${NC}"
        echo ""
        wait_for_enter
        return 1
    fi
}

# Unified vault add flow
# Parameters: mode (new|existing), secret_count, secrets_array_elements...
add_vault() {
    local mode="$1"
    local secret_count="$2"
    shift 2
    local -a secrets=("$@")

    local vault_name
    local vault_location
    local cipher_dir
    local mount_point

    # Step 1: Get vault name and location (mode-specific)
    if [ "$mode" = "new" ]; then
        # New vault: ask for name first
        clear
        print_header "NEW VAULT"
        echo ""
        echo -e "${BRIGHT_WHITE}Enter vault name${NC} ${DIM}(or press ESC to cancel)${NC}"
        echo -ne "${BRIGHT_WHITE}Name:${NC} "
        read_with_esc_cancel vault_name
        local read_result=$?

        if [ $read_result -eq 2 ] || [ -z "$vault_name" ]; then
            return 1
        fi

        # Select parent folder; vault will be created as a subfolder named after the vault
        unset SELECTED_PROJECTS_DIR
        show_interactive_browser "directory" "$HOME" "/home" "Select: Parent Folder" "false" "true"

        if [ -z "$SELECTED_PROJECTS_DIR" ]; then
            return 1
        fi

        vault_location="$SELECTED_PROJECTS_DIR/$vault_name"
    else
        # Existing vault: select the vault's parent folder
        unset SELECTED_PROJECTS_DIR
        show_interactive_browser "directory" "$HOME" "/home" "Select: Vault Location" "false" "true"

        if [ -z "$SELECTED_PROJECTS_DIR" ]; then
            return 1
        fi

        vault_location="$SELECTED_PROJECTS_DIR"

        # Verify it contains a valid gocryptfs vault at the cipher subdir
        if [ ! -f "$vault_location/cipher/gocryptfs.conf" ]; then
            clear
            print_header "RE-REGISTER"
            echo ""
            echo -e "${BRIGHT_RED}No vault found at this location${NC}"
            echo -e "${DIM}Path:${NC} ${vault_location/#$HOME/\~}"
            echo -e "${DIM}Expected a ${NC}cipher/${DIM} subfolder with a gocryptfs vault inside.${NC}"
            echo -e "${DIM}Only vaults created by this tool can be re-registered.${NC}"
            echo ""
            wait_for_enter
            return 1
        fi

        # Derive vault name from the location folder
        vault_name=$(basename "$vault_location")
    fi

    cipher_dir="$vault_location/cipher"
    mount_point="$vault_location/mount"

    # Step 2: Select secret (common)
    local secret_id
    local encrypted_passphrase
    if ! select_secret_interactive "$secret_count" "${secrets[@]}"; then
        return 1
    fi
    secret_id="$SECRET_ID_RESULT"
    encrypted_passphrase="$PASSPHRASE_RESULT"

    # Step 3: Initialize vault if new (mode-specific)
    if [ "$mode" = "new" ]; then
        clear
        print_header "INITIALIZING VAULT"
        echo ""
        echo -e "${DIM}Vault location:${NC} ${vault_location/#$HOME/\~}"
        echo ""
        echo -e "${DIM}Initializing...${NC}"
        if ! init_vault "$cipher_dir" "$secret_id"; then
            echo ""
            echo -e "${BRIGHT_RED}Failed to initialize vault${NC}"
            wait_for_enter
            return 1
        fi
        echo -e "${BRIGHT_GREEN}✓${NC} Vault initialized"
    fi

    # Step 4: Save vault config (common)
    if save_vault "$vault_name" "$vault_location" "$cipher_dir" "$mount_point" "$secret_id"; then
        clear
        print_header "VAULT ADDED"
        echo ""
        if [ "$mode" = "new" ]; then
            echo -e "${BRIGHT_GREEN}✓${NC} Vault created successfully!"
        else
            echo -e "${BRIGHT_GREEN}✓${NC} Vault re-registered successfully!"
        fi
        echo ""
        echo -e "${DIM}Name:${NC} ${BRIGHT_WHITE}$vault_name${NC}"
        echo -e "${DIM}Location:${NC} ${vault_location/#$HOME/\~}"
        echo -e "${DIM}Secret:${NC} $(basename "$encrypted_passphrase")"
        echo ""
        wait_for_enter
        return 0
    else
        clear
        print_header "ERROR"
        echo ""
        echo -e "${BRIGHT_RED}Failed to save vault${NC}"
        echo ""
        wait_for_enter
        return 1
    fi
}

# Helper function to select secret interactively
# Parameters: secret_count, secrets_array_elements...
# Returns: 0 on success, 1 on cancel
# Output: Sets SECRET_ID_RESULT and PASSPHRASE_RESULT globals
select_secret_interactive() {
    local secret_count="$1"
    shift
    local -a secrets=("$@")

    clear
    print_header "SELECT SECRET"
    echo ""
    local counter=1
    for secret_info in "${secrets[@]}"; do
        IFS=':' read -r id private_key _ encrypted_passphrase <<< "$secret_info"
        local display_age=$(basename "$encrypted_passphrase")
        printf "${BRIGHT_CYAN}%2s${NC}  %s\n" "$counter" "$display_age"
        counter=$((counter + 1))
    done
    echo ""
    echo -e "${DIM}Press ESC to cancel${NC}"
    echo -ne "${BRIGHT_WHITE}Secret number:${NC} "
    local secret_num
    read_with_esc_cancel secret_num
    local read_result=$?

    if [ $read_result -eq 2 ] || [ -z "$secret_num" ]; then
        return 1
    fi

    if ! [[ "$secret_num" =~ ^[0-9]+$ ]] || [ "$secret_num" -lt 1 ] || [ "$secret_num" -gt "$secret_count" ]; then
        clear
        print_header "ERROR"
        echo ""
        echo -e "${BRIGHT_RED}Invalid secret number${NC}"
        echo ""
        wait_for_enter
        return 1
    fi

    local secret_index=$((secret_num - 1))
    local selected_secret="${secrets[$secret_index]}"
    IFS=':' read -r SECRET_ID_RESULT _ _ PASSPHRASE_RESULT <<< "$selected_secret"

    return 0
}
