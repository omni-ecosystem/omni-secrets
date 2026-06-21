#!/bin/bash

# ========================================
# Vault Manage Module
# ========================================
# Per-vault management screen
# Usage: source libs/omni-secrets/vaults/manage.sh

# Show the management screen for a specific vault
# Parameters: vault_index (0-based)
# Returns: 0 always
show_manage_vault_screen() {
    local vault_index="$1"

    while true; do
        local -a vaults=()
        local -a secrets=()
        load_vaults vaults
        load_secrets secrets

        local vault_info="${vaults[$vault_index]}"
        IFS=':' read -r name vault_location cipher_dir mount_point secret_id <<< "$vault_info"

        local secret_count=${#secrets[@]}

        # Build current secret display
        local secret_display="${DIM}-${NC}"
        local secret_data
        if secret_data=$(get_secret_by_id "$secret_id"); then
            IFS=':' read -r _ private_key _ _ <<< "$secret_data"
            secret_display="${BRIGHT_WHITE}$(basename "$private_key")${NC}"
        fi

        local status_label="${DIM}unmounted${NC}"
        if get_vault_status "$mount_point"; then
            status_label="${BRIGHT_GREEN}mounted${NC}"
        fi

        printf '\033[?25l'
        clear
        print_header "MANAGE VAULT"
        echo ""
        echo -e "  ${BOLD}\"$name\"${NC}  ${DIM}(${NC}${status_label}${DIM})${NC}"
        echo ""
        if [ -n "$vault_location" ]; then
            echo -e "  ${DIM}vault location:${NC}  ${vault_location/#$HOME/\~}"
        else
            echo -e "  ${DIM}cipher dir:${NC}   ${cipher_dir/#$HOME/\~}"
            echo -e "  ${DIM}mount point:${NC}  ${mount_point/#$HOME/\~}"
        fi
        echo -e "  ${DIM}secret:${NC}       $(echo -e "$secret_display")"
        echo ""

        if [ -n "$vault_location" ]; then
            menu_line \
                "$(menu_cmd 'l' 'location' "$MENU_COLOR_ACTION")" \
                "$([[ $secret_count -gt 0 ]] && menu_cmd 's' 'switch secret' "$MENU_COLOR_OPEN")" \
                "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")"
        else
            menu_line \
                "$(menu_cmd 'c' 'cipher dir' "$MENU_COLOR_ACTION")" \
                "$(menu_cmd 'm' 'mount point' "$MENU_COLOR_ACTION")" \
                "$([[ $secret_count -gt 0 ]] && menu_cmd 's' 'switch secret' "$MENU_COLOR_OPEN")" \
                "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")"
        fi
        echo ""

        printf '\033[?25h'
        echo -ne "${BRIGHT_CYAN}>${NC} "
        local choice
        read_with_instant_back choice

        case "$choice" in
            [Bb]) return 0 ;;
            [Ll])
                if [ -n "$vault_location" ]; then
                    unset SELECTED_PROJECTS_DIR
                    show_interactive_browser "directory" "$HOME" "/home" "Select: Vault Location" "false" "true"

                    if [ -n "$SELECTED_PROJECTS_DIR" ]; then
                        if update_vault_location "$vault_index" "$SELECTED_PROJECTS_DIR"; then
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_GREEN}✓${NC} Vault location updated"
                            echo ""
                            wait_for_enter
                        else
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_RED}✗${NC} Failed to update vault location"
                            echo ""
                            wait_for_enter
                        fi
                    fi
                fi
                ;;
            [Cc])
                if [ -z "$vault_location" ]; then
                    unset SELECTED_PROJECTS_DIR
                    show_interactive_browser "directory" "$HOME" "/home" "Select: Cipher Directory" "false" "true"

                    if [ -n "$SELECTED_PROJECTS_DIR" ]; then
                        local new_cipher_dir="$SELECTED_PROJECTS_DIR"
                        unset SELECTED_PROJECTS_DIR

                        if update_vault_cipher_dir "$vault_index" "$new_cipher_dir"; then
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_GREEN}✓${NC} Cipher directory updated"
                            echo ""
                            wait_for_enter
                        else
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_RED}✗${NC} Failed to update cipher directory"
                            echo ""
                            wait_for_enter
                        fi
                    fi
                fi
                ;;
            [Mm])
                if [ -z "$vault_location" ]; then
                    unset SELECTED_PROJECTS_DIR
                    show_interactive_browser "directory" "$HOME" "/home" "Select: Mount Point" "false" "true"

                    if [ -n "$SELECTED_PROJECTS_DIR" ]; then
                        local new_mount_point="$SELECTED_PROJECTS_DIR"
                        unset SELECTED_PROJECTS_DIR

                        if update_vault_mount_point "$vault_index" "$new_mount_point"; then
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_GREEN}✓${NC} Mount point updated"
                            echo ""
                            wait_for_enter
                        else
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_RED}✗${NC} Failed to update mount point"
                            echo ""
                            wait_for_enter
                        fi
                    fi
                fi
                ;;
            [Ss])
                if [ "$secret_count" -gt 0 ]; then
                    if select_secret_interactive "$secret_count" "${secrets[@]}"; then
                        if update_vault_secret "$vault_index" "$SECRET_ID_RESULT"; then
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_GREEN}✓${NC} Secret updated successfully"
                            echo ""
                            wait_for_enter
                        else
                            clear
                            print_header "MANAGE VAULT"
                            echo ""
                            echo -e "${BRIGHT_RED}✗${NC} Failed to update secret"
                            echo ""
                            wait_for_enter
                        fi
                    fi
                fi
                ;;
        esac
    done
}
