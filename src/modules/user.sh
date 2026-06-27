#!/bin/bash

# User creation and configuration module

ensure_non_root_user_or_create() {
    # If running under sudo, SUDO_USER is the invoking non-root user.
    # If empty or root, we're in a root session – require creating a normal user.
    local invoking_user
    invoking_user="${SUDO_USER:-}"

    if [[ -z "$invoking_user" || "$invoking_user" == "root" ]]; then
        log_warn "Running as root is not recommended. A regular sudo user is required."

        local create_now
        create_now=$(confirm "Create a regular sudo user now?")
        if [[ "$create_now" != "y" ]]; then
            log_error "Create a regular user and run the script via sudo. Exiting."
            return 1
        fi

        local NEW_USER NEW_PASS NEW_PASS_CONFIRM
        NEW_USER=$(get_input "Enter new username" "admin")

        log_info "Creating user $NEW_USER..."
        if ! id -u "$NEW_USER" >/dev/null 2>&1; then
            sudo adduser --gecos "" "$NEW_USER"
        else
            log_warn "User $NEW_USER already exists. Skipping creation."
        fi

        log_info "Setting password..."
        echo "$NEW_USER:$NEW_PASS" | sudo chpasswd

        log_info "Configuring sudo access for $NEW_USER..."
        echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$NEW_USER" >/dev/null
        sudo chmod 0440 "/etc/sudoers.d/$NEW_USER"

        # Copy SSH keys from root if present
        if [[ -f /root/.ssh/authorized_keys ]]; then
            log_info "Copying SSH keys from /root for $NEW_USER..."
            sudo mkdir -p "/home/$NEW_USER/.ssh"
            sudo cp /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/authorized_keys"
            sudo chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
            sudo chmod 700 "/home/$NEW_USER/.ssh"
            sudo chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
        else
            log_warn "/root/.ssh/authorized_keys not found. Key-based access is not configured."
        fi

        log_info "User $NEW_USER is ready. Sign in as this user and re-run the script with sudo."
        log_info "Commands:"
        log_info "  su - $NEW_USER"
        log_info "  sudo ./src/main.sh"

        return 1
    fi

    # OK — invoked via sudo by a regular user
    log_info "Detected regular sudo user: $invoking_user"
    return 0
}
