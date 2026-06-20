#!/bin/bash

# ========================================
# Secrets Components Module
# ========================================
# UI display components for secrets
# Usage: source libs/omni-secrets/components.sh

# Column width for side-by-side display
SECRETS_COL_WIDTH=58

# Max lengths for truncation
MAX_FILENAME_LEN=24
MAX_PATH_LEN=30

# Strip ANSI codes for length calculation
strip_ansi() {
    echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Pad string to width (accounting for ANSI codes)
pad_to_width() {
    local str="$1"
    local width="$2"
    local stripped=$(strip_ansi "$str")
    local visible_len=${#stripped}
    local padding=$((width - visible_len))
    printf "%s" "$str"
    [ $padding -gt 0 ] && printf "%${padding}s" ""
}

# Truncate filename with ellipsis
truncate_filename() {
    local name="$1"
    local max_len="${2:-$MAX_FILENAME_LEN}"
    if [ ${#name} -gt $max_len ]; then
        echo "${name:0:$((max_len-3))}..."
    else
        echo "$name"
    fi
}

# Fish-style path shortening: ~/really/long/path/to/dir → ~/r/l/p/t/dir
# Only shortens if path exceeds max length
shorten_path() {
    local path="$1"
    local max_len="${2:-$MAX_PATH_LEN}"

    # If path is short enough, return as-is
    [ ${#path} -le $max_len ] && echo "$path" && return

    # Split path into parts
    local prefix=""
    local work_path="$path"

    # Handle ~/ prefix
    if [[ "$path" == "~/"* ]]; then
        prefix="~/"
        work_path="${path:2}"
    elif [[ "$path" == "/"* ]]; then
        prefix="/"
        work_path="${path:1}"
    fi

    # Split into array
    IFS='/' read -ra parts <<< "$work_path"
    local num_parts=${#parts[@]}

    # Keep last part full, shorten others to first char
    local result="$prefix"
    for ((i=0; i<num_parts-1; i++)); do
        local part="${parts[$i]}"
        [ -n "$part" ] && result+="${part:0:1}/"
    done
    result+="${parts[$num_parts-1]}"

    echo "$result"
}

# Display secrets and vaults side by side
# Parameters: secrets_array_ref, vaults_array_ref
display_secrets_and_vaults() {
    local -n secrets_ref=$1
    local -n vaults_ref=$2

    local secret_count=${#secrets_ref[@]}
    local vault_count=${#vaults_ref[@]}

    # Build left column (secrets)
    local -a left_lines=()
    left_lines+=("")

    if [ "$secret_count" -eq 0 ]; then
        left_lines+=("${DIM}No secrets configured.${NC}")
    else
        local counter=1
        for secret_info in "${secrets_ref[@]}"; do
            IFS=':' read -r id private_key public_key encrypted_passphrase <<< "$secret_info"
            local display_private=$(truncate_filename "$(basename "$private_key")")
            local display_public=$(truncate_filename "$(basename "$public_key")")
            local display_passphrase=$(truncate_filename "$(basename "$encrypted_passphrase")")
            local display_name=$(truncate_filename "${display_private%.age}" 18)

            left_lines+=("${BRIGHT_CYAN}Secret #$counter${NC} ${BOLD}\"${display_name}\"${NC}")
            left_lines+=("  ${DIM}private key:${NC}      $display_private")
            left_lines+=("  ${DIM}public key:${NC}       $display_public")
            left_lines+=("  ${DIM}passphrase file:${NC}  $display_passphrase")
            left_lines+=("")
            counter=$((counter + 1))
        done
    fi

    # Build right column (vaults)
    local -a right_lines=()
    right_lines+=("")

    if [ "$vault_count" -eq 0 ]; then
        right_lines+=("${DIM}No vaults configured.${NC}")
    else
        local counter=1
        for vault_info in "${vaults_ref[@]}"; do
            IFS=':' read -r name cipher_dir mount_point secret_id <<< "$vault_info"

            local status_icon="${DIM}○${NC}"
            if get_vault_status "$mount_point"; then
                status_icon="${BRIGHT_GREEN}●${NC}"
            fi

            local secret_display="-"
            local secret_data
            if secret_data=$(get_secret_by_id "$secret_id"); then
                IFS=':' read -r sid private_key _ _ <<< "$secret_data"
                local secret_name=$(basename "$private_key")
                secret_name=$(truncate_filename "${secret_name%.age}" 14)

                # Find human-readable index (matches "Secret #N" in left column)
                local human_id=0
                local idx=1
                for s in "${secrets_ref[@]}"; do
                    IFS=':' read -r check_id _ _ _ <<< "$s"
                    if [[ "$check_id" == "$sid" ]]; then
                        human_id=$idx
                        break
                    fi
                    ((idx++))
                done

                if [ $human_id -gt 0 ]; then
                    secret_display="${secret_name} #${human_id}"
                else
                    secret_display="${secret_name}"
                fi
            fi

            local display_cipher=$(shorten_path "${cipher_dir/#$HOME/\~}")
            local display_mount=$(shorten_path "${mount_point/#$HOME/\~}")
            local display_name=$(truncate_filename "$name" 18)

            right_lines+=("$status_icon ${BRIGHT_CYAN}Vault #$counter${NC} ${BOLD}\"${display_name}\"${NC}")
            right_lines+=("  ${DIM}secret:${NC}      $secret_display")
            right_lines+=("  ${DIM}cipher dir:${NC}  $display_cipher")
            right_lines+=("  ${DIM}mount dir:${NC}   $display_mount")
            right_lines+=("")
            counter=$((counter + 1))
        done
    fi

    # Print side by side
    local max_lines=${#left_lines[@]}
    [ ${#right_lines[@]} -gt $max_lines ] && max_lines=${#right_lines[@]}

    echo ""
    for ((i=0; i<max_lines; i++)); do
        local left="${left_lines[$i]:-}"
        local right="${right_lines[$i]:-}"
        pad_to_width " $left" "$SECRETS_COL_WIDTH"
        echo -e "$right"
    done
    echo ""
}

# Display help/documentation for the secrets module
display_secrets_help() {
    clear
    print_header "Secrets Help"
    echo ""
    echo -e "${DIM}This tool uses ${NC}${BOLD}user-generated ${NC}${BRIGHT_CYAN}age${NC}${DIM} keypairs to manage ${NC}${BRIGHT_CYAN}gocryptfs${NC}${DIM} volumes (aka vaults).${NC}"
    echo ""
    echo -e "${DIM}To add a secret, provide an encrypted passphrase (${NC}${ITALIC}.age${NC}${DIM}) and its corresponding ${NC}${ITALIC}keypairs${NC}${DIM}.${NC}"
    echo -e "${DIM}Secrets are then used to create, mount and unmount ${NC}${ITALIC}vaults${NC}${DIM}. Existing vaults that relies on .age can also be managed.${NC}"
    echo ""
    echo -e "${DIM}How it works:${NC}"
    echo -e "  ${BRIGHT_WHITE}create passphrase${NC} ${DIM}→${NC} ${BRIGHT_WHITE}encrypt with age${NC} ${DIM}→${NC} ${BRIGHT_CYAN}.age file and keypair${NC} ${DIM}→${NC} ${BRIGHT_WHITE}add it here (a secret!)${NC} ${DIM}→${NC} ${BRIGHT_CYAN}manage vault(s)${NC}"
    echo ""
    echo -e "${BOLD}Storage location:${NC}${DIM} Secrets and vault metadata live in ${NC}${ITALIC}one shared directory${NC}${DIM} on disk (shown as ${NC}${BRIGHT_CYAN}Secrets dir${NC}${DIM} on the previous screen) - the same place is used no matter how many projects or vaults you manage.${NC}"
    echo -e "${DIM}Press ${NC}${BRIGHT_CYAN}c${NC}${DIM} from the previous screen to relocate it. The new location takes effect after restarting the app; existing files are not moved automatically.${NC}"
    echo ""
    echo -e "${BOLD}Files and folders are not touched:${NC}${DIM} This tool only ${ITALIC}manages${NC} the secrets and vaults. Deletion of those files should be user's responsibility.${NC}"
    echo ""
    echo -e "${BRIGHT_CYAN}age${NC} — simple, modern file encryption tool (${BRIGHT_CYAN}https://github.com/FiloSottile/age${NC})"
    echo -e "${BRIGHT_CYAN}gocryptfs${NC} — encrypted overlay filesystem (${BRIGHT_CYAN}https://github.com/rfjakob/gocryptfs${NC})"
    echo ""
    echo -e "Check *this* project's documentation to understand this approach in deep. (${BRIGHT_CYAN}https://placeholder${NC})" # Placeholder URL, project's doc will be *this* project's doc
    echo ""

    wait_for_enter
}
