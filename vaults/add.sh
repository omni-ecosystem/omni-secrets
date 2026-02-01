#!/bin/bash

# ========================================
# Vault Add Module
# ========================================
# Add vault flow
# Usage: source libs/omni-secrets/vaults/add.sh

# Global variables for select_secret_interactive results
declare -g SECRET_ID_RESULT=""
declare -g PASSPHRASE_RESULT=""

# Validate cipher dir and mount point are different
# Parameters: cipher_dir, mount_point
# Returns: 0 if valid, 1 if same location
validate_vault_paths() {
    local cipher_dir="$1"
    local mount_point="$2"

    if [ "$(realpath "$cipher_dir")" = "$(realpath "$mount_point")" ]; then
        clear
        print_header "ERROR"
        echo ""
        echo -e "${BRIGHT_RED}Cipher directory and mount point cannot be the same${NC}"
        echo ""
        echo -e "${DIM}Cipher dir:${NC} ${cipher_dir/#$HOME/\~}"
        echo -e "${DIM}Mount point:${NC} ${mount_point/#$HOME/\~}"
        echo ""
        echo -e "${DIM}The mount point must be a different location from the cipher directory.${NC}"
        echo ""
        wait_for_enter
        return 1
    fi
    return 0
}

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
    echo -e "${BRIGHT_WHITE}What would you like to add?${NC}"
    echo ""
    echo -e "${BRIGHT_CYAN}1${NC}  New vault ${DIM}(create and initialize)${NC}"
    echo -e "${BRIGHT_CYAN}2${NC}  Existing vault ${DIM}(already initialized)${NC}"
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
        # EXISTING VAULT FLOW
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
    local cipher_dir
    local mount_point

    # Step 1: Get vault name and cipher directory (mode-specific)
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

        # Select cipher directory
        unset SELECTED_PROJECTS_DIR
        show_interactive_browser "directory" "$HOME" "/home" "Select: Cipher Directory" "false" "true"

        if [ -z "$SELECTED_PROJECTS_DIR" ]; then
            return 1
        fi

        cipher_dir="$SELECTED_PROJECTS_DIR"
    else
        # Existing vault: select cipher directory first
        unset SELECTED_PROJECTS_DIR
        show_interactive_browser "directory" "$HOME" "/home" "Select: Cipher Directory (vault location)" "false" "true"

        if [ -z "$SELECTED_PROJECTS_DIR" ]; then
            return 1
        fi

        cipher_dir="$SELECTED_PROJECTS_DIR"

        # Verify it's a valid gocryptfs vault
        if [ ! -f "$cipher_dir/gocryptfs.conf" ]; then
            clear
            print_header "ERROR"
            echo ""
            echo -e "${BRIGHT_RED}Not a valid gocryptfs vault${NC}"
            echo -e "${DIM}Path:${NC} ${cipher_dir/#$HOME/\~}"
            echo -e "${DIM}Missing gocryptfs.conf file${NC}"
            echo ""
            wait_for_enter
            return 1
        fi

        # Derive vault name from cipher directory
        vault_name=$(basename "$cipher_dir")
    fi

    # Step 2: Select mount point (common)
    unset SELECTED_PROJECTS_DIR
    show_interactive_browser "directory" "$HOME" "/home" "Select: Mount Point" "false" "true"

    if [ -z "$SELECTED_PROJECTS_DIR" ]; then
        return 1
    fi

    mount_point="$SELECTED_PROJECTS_DIR"

    # Step 3: Validate paths are different (common)
    if ! validate_vault_paths "$cipher_dir" "$mount_point"; then
        return 1
    fi

    # Step 4: Select secret (common)
    local secret_id
    local encrypted_passphrase
    if ! select_secret_interactive "$secret_count" "${secrets[@]}"; then
        return 1
    fi
    secret_id="$SECRET_ID_RESULT"
    encrypted_passphrase="$PASSPHRASE_RESULT"

    # Step 5: Initialize vault if new (mode-specific)
    if [ "$mode" = "new" ]; then
        clear
        print_header "INITIALIZING VAULT"
        echo ""
        echo -e "${DIM}Cipher dir:${NC} ${cipher_dir/#$HOME/\~}"
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

    # Step 6: Save vault config (common)
    if save_vault "$vault_name" "$cipher_dir" "$mount_point" "$secret_id"; then
        clear
        print_header "VAULT ADDED"
        echo ""
        if [ "$mode" = "new" ]; then
            echo -e "${BRIGHT_GREEN}✓${NC} Vault added successfully!"
        else
            echo -e "${BRIGHT_GREEN}✓${NC} Existing vault added successfully!"
        fi
        echo ""
        echo -e "${DIM}Name:${NC} ${BRIGHT_WHITE}$vault_name${NC}"
        echo -e "${DIM}Cipher dir:${NC} ${cipher_dir/#$HOME/\~}"
        echo -e "${DIM}Mount point:${NC} ${mount_point/#$HOME/\~}"
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
