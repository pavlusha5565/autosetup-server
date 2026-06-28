#!/bin/bash

# User creation and configuration module

_configure_sudoers() {
    local user="$1"
    local answer
    read -rp "Grant $user NOPASSWD sudo access? [y/N]: " answer
    if [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]; then
        echo "$user ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$user" >/dev/null
        sudo chmod 0440 "/etc/sudoers.d/$user"
        log_info "Sudo access granted to $user."
    else
        log_warn "Skipping sudo configuration for $user."
    fi
}

_list_ssh_sources() {
    local new_user="$1"
    local -a options=()

    # root
    if [[ -f /root/.ssh/authorized_keys ]]; then
        options+=("root")
    fi

    # all home dirs except the new user itself
    while IFS= read -r home_dir; do
        local uname
        uname=$(basename "$home_dir")
        if [[ "$uname" != "$new_user" && -f "$home_dir/.ssh/authorized_keys" ]]; then
            options+=("$uname")
        fi
    done < <(find /home -maxdepth 1 -mindepth 1 -type d 2>/dev/null)

    options+=("create" "skip")
    printf '%s\n' "${options[@]}"
}

_interactive_select() {
    local prompt="$1"
    shift
    local -a items=("$@")
    local selected=0
    local key esc

    # hide cursor
    tput civis 2>/dev/null

    _draw_menu() {
        local i
        for i in "${!items[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  \033[1;32m> ${items[$i]}\033[0m"
            else
                echo "    ${items[$i]}"
            fi
        done
    }

    echo "$prompt"
    _draw_menu

    while true; do
        # read single keypress (handles arrow keys as escape sequences)
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 key
            case "$key" in
                '[A') # up
                    (( selected > 0 )) && (( selected-- ))
                    ;;
                '[B') # down
                    (( selected < ${#items[@]} - 1 )) && (( selected++ ))
                    ;;
            esac
        elif [[ "$key" == "" || "$key" == $'\n' ]]; then
            break
        fi
        # redraw
        tput cuu "${#items[@]}" 2>/dev/null
        _draw_menu
    done

    tput cnorm 2>/dev/null
    echo "${items[$selected]}"
}

_configure_ssh_keys() {
    local new_user="$1"
    local dest_ssh="/home/$new_user/.ssh"
    local dest_keys="$dest_ssh/authorized_keys"

    mapfile -t sources < <(_list_ssh_sources "$new_user")

    local choice
    choice=$(_interactive_select "Select SSH key source for $new_user:" "${sources[@]}")
    echo "Selected: $choice"

    case "$choice" in
        skip)
            log_warn "Skipping SSH key configuration."
            ;;
        create)
            log_info "Generating new Ed25519 key pair for $new_user..."
            sudo mkdir -p "$dest_ssh"
            sudo ssh-keygen -t ed25519 -C "$new_user@$(hostname)" -f "$dest_ssh/id_ed25519" -N "" >/dev/null
            sudo cat "$dest_ssh/id_ed25519.pub" | sudo tee "$dest_keys" >/dev/null
            sudo chown -R "$new_user:$new_user" "$dest_ssh"
            sudo chmod 700 "$dest_ssh"
            sudo chmod 600 "$dest_keys"
            log_info "New key pair generated. Public key:"
            sudo cat "$dest_ssh/id_ed25519.pub"
            ;;
        root)
            log_info "Copying SSH keys from /root..."
            sudo mkdir -p "$dest_ssh"
            sudo cp /root/.ssh/authorized_keys "$dest_keys"
            sudo chown -R "$new_user:$new_user" "$dest_ssh"
            sudo chmod 700 "$dest_ssh"
            sudo chmod 600 "$dest_keys"
            log_info "Keys copied from root."
            ;;
        *)
            # another user
            local src_keys="/home/$choice/.ssh/authorized_keys"
            log_info "Copying SSH keys from $choice..."
            sudo mkdir -p "$dest_ssh"
            sudo cp "$src_keys" "$dest_keys"
            sudo chown -R "$new_user:$new_user" "$dest_ssh"
            sudo chmod 700 "$dest_ssh"
            sudo chmod 600 "$dest_keys"
            log_info "Keys copied from $choice."
            ;;
    esac
}

setup_user() {
    local NEW_USER
    NEW_USER=$(get_input "Enter new username" "admin")

    log_info "Creating user $NEW_USER..."
    if ! id -u "$NEW_USER" >/dev/null 2>&1; then
        sudo adduser --gecos "" "$NEW_USER"
    else
        log_warn "User $NEW_USER already exists. Skipping creation."
    fi

    _configure_sudoers "$NEW_USER"

    _configure_ssh_keys "$NEW_USER"

    log_info "User $NEW_USER is ready. Sign in as this user and re-run the script with sudo."
    log_info "Commands:"
    log_info "  su - $NEW_USER"
    log_info "  sudo ./src/main.sh"

    return 1
}
