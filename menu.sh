#!/bin/bash

# ========================================
# Secrets Menu Module
# ========================================
# Main menu screen and entry point for secrets
# Usage: source libs/omni-secrets/menu.sh

# Default secrets screen
# Returns: 0 = stay, 1 = back to settings, 2 = add secret, 3 = show help, 4 = add vault
show_secrets_default_screen() {
    local -a secrets=()
    local -a vaults=()
    load_secrets secrets
    load_vaults vaults
    local secret_count=${#secrets[@]}
    local vault_count=${#vaults[@]}

    printf '\033[?25l'
    clear
    print_header "Secrets & Vaults"
    echo -e "${DIM}Secrets config:${NC} $(get_secrets_config_directory)"

    # Display secrets and vaults side by side
    display_secrets_and_vaults secrets vaults

    # Build and display menu commands
    echo ""
    menu_line \
        "$(menu_cmd 'a' 'add secret' "$MENU_COLOR_ADD")" \
        "$([[ $secret_count -gt 0 ]] && menu_cmd 'v' 'add vault' "$MENU_COLOR_ADD")" \
        "$(menu_num_cmd 'm' "$vault_count" 'mount' "$MENU_COLOR_ACTION")" \
        "$(menu_num_cmd 'u' "$vault_count" 'unmount' "$MENU_COLOR_ACTION")" \
        "$([[ $vault_count -gt 0 ]] && menu_num_cmd 'e' "$vault_count" 'manage vault' "$MENU_COLOR_OPEN")" \
        "$(menu_num_cmd 'd' "$secret_count" 'delete secret' "$MENU_COLOR_DELETE")" \
        "$(menu_num_cmd 'r' "$vault_count" 'remove vault' "$MENU_COLOR_DELETE")" \
        "$(menu_cmd 'c' 'change dir' "$MENU_COLOR_NAV")" \
        "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")" \
        "$(menu_cmd 'h' 'help' "$MENU_COLOR_NAV")"
    echo ""

    printf '\033[?25h'
    echo -ne "${BRIGHT_CYAN}>${NC} "
    local choice
    read_with_instant_back choice

    case "$choice" in
        [Bb]) return 1 ;;
        [Hh]) return 3 ;;
        [Cc]) return 5 ;;
        [Aa])
            show_add_secret_flow
            return 0
            ;;
        [Vv])
            if [ "$secret_count" -gt 0 ]; then
                return 4
            fi
            return 0
            ;;
    esac

    # Handle mount commands (m1, m2, etc.)
    if [[ "$choice" =~ ^[Mm]([0-9]+)$ ]]; then
        local mount_num="${BASH_REMATCH[1]}"
        if [ "$mount_num" -ge 1 ] && [ "$mount_num" -le "$vault_count" ]; then
            local mount_index=$((mount_num - 1))
            if ! mount_vault "$mount_index"; then
                wait_for_enter
            fi
        fi
        return 0
    fi

    # Handle unmount commands (u1, u2, etc.)
    if [[ "$choice" =~ ^[Uu]([0-9]+)$ ]]; then
        local unmount_num="${BASH_REMATCH[1]}"
        if [ "$unmount_num" -ge 1 ] && [ "$unmount_num" -le "$vault_count" ]; then
            local unmount_index=$((unmount_num - 1))
            if ! unmount_vault "$unmount_index"; then
                wait_for_enter
            fi
        fi
        return 0
    fi

    # Handle manage vault commands (e1, e2, etc.)
    if [[ "$choice" =~ ^[Ee]([0-9]+)$ ]]; then
        local manage_num="${BASH_REMATCH[1]}"
        if [ "$manage_num" -ge 1 ] && [ "$manage_num" -le "$vault_count" ]; then
            local manage_index=$((manage_num - 1))
            show_manage_vault_screen "$manage_index"
        fi
        return 0
    fi

    # Handle delete commands (d1, d2, etc.) - for secrets
    if [[ "$choice" =~ ^[Dd]([0-9]+)$ ]]; then
        local delete_num="${BASH_REMATCH[1]}"
        if [ "$delete_num" -ge 1 ] && [ "$delete_num" -le "$secret_count" ]; then
            local delete_index=$((delete_num - 1))
            local secret_info="${secrets[$delete_index]}"
            IFS=':' read -r _ private_key _ _ <<< "$secret_info"
            local secret_name=$(basename "$private_key")

            # Confirmation prompt
            echo -ne "${BRIGHT_YELLOW}Delete secret '$secret_name'? (y/n):${NC} "
            local confirm
            read_with_instant_back confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                delete_secret "$delete_index"
            fi
        fi
        return 0
    fi

    # Handle remove commands (r1, r2, etc.) - for vaults
    if [[ "$choice" =~ ^[Rr]([0-9]+)$ ]]; then
        local remove_num="${BASH_REMATCH[1]}"
        if [ "$remove_num" -ge 1 ] && [ "$remove_num" -le "$vault_count" ]; then
            local remove_index=$((remove_num - 1))
            local vault_info="${vaults[$remove_index]}"
            IFS=':' read -r name _ mount_point _ <<< "$vault_info"

            # Check if mounted
            if get_vault_status "$mount_point"; then
                echo -e "${BRIGHT_RED}Cannot remove mounted vault '$name'. Unmount first.${NC}"
                wait_for_enter
            else
                # Confirmation prompt
                echo -ne "${BRIGHT_YELLOW}Remove vault '$name'? (y/n):${NC} "
                local confirm
                read_with_instant_back confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    delete_vault "$remove_index"
                fi
            fi
        fi
        return 0
    fi

    return 0
}

# Change secrets directory screen
# Lets the user point omni-secrets at a different storage location. Persistence
# is host-specific, so we hand the new path to on_omni_secrets_data_dir_change
# (defined by the consuming app) if it exists - omni-secrets itself only knows
# how to read from OMNI_SECRETS_DATA_DIR, not how the host persists config.
# Returns: 0 always
show_change_secrets_dir_screen() {
    local current_dir
    current_dir=$(get_secrets_config_directory)

    show_interactive_browser "directory" "$HOME" "/home" "Select: Secrets Storage Directory"

    if [ -z "$SELECTED_PROJECTS_DIR" ]; then
        return 0
    fi

    local new_dir="$SELECTED_PROJECTS_DIR"
    unset SELECTED_PROJECTS_DIR

    if [ "$new_dir" = "$current_dir" ]; then
        return 0
    fi

    if type on_omni_secrets_data_dir_change &>/dev/null; then
        on_omni_secrets_data_dir_change "$new_dir"
    fi

    echo ""
    print_success "Secrets directory set to: $new_dir"
    print_warning "Restart the app for this to take effect. Existing secrets won't be moved automatically."
    wait_for_enter
    return 0
}

# Main secrets menu entry point
show_secrets_menu() {
    while true; do
        local result
        show_secrets_default_screen
        result=$?

        case $result in
            1) return 0 ;;  # Back to settings
            3)              # Show help screen
                display_secrets_help
                ;;
            4)              # Add vault
                show_add_vault_screen
                ;;
            5)              # Change secrets directory
                show_change_secrets_dir_screen
                ;;
        esac
    done
}
