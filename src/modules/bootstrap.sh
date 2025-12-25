#!/bin/bash

# Initial system setup module

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

        while true; do
            NEW_PASS=$(get_hidden_input "Enter password for user $NEW_USER" "")
            NEW_PASS_CONFIRM=$(get_hidden_input "Retype password for user $NEW_USER" "")
            if [[ -z "$NEW_PASS" ]]; then
                log_warn "Password cannot be empty. Please try again."
                continue
            fi
            if [[ "$NEW_PASS" == "$NEW_PASS_CONFIRM" ]]; then
                break
            else
                log_error "Passwords do not match. Please try again."
            fi
        done

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

setup_unattended_upgrades() {
    log_info "Installing and configuring unattended-upgrades..."
    
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qq
    install_packages unattended-upgrades

    # Configure APT periodic updates
    log_info "Configuring APT periodic updates..."
    sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    # Configure unattended-upgrades to install only security updates
    log_info "Configuring security-only updates..."
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        local CODENAME="${VERSION_CODENAME:-$(lsb_release -sc 2>/dev/null || echo stable)}"
        local PATTERN=""
        
        case "${ID:-}" in
            debian)
                PATTERN="\"origin=Debian,codename=${CODENAME}-security,label=Debian-Security\";"
                ;;
            ubuntu)
                PATTERN="\"origin=Ubuntu,codename=${CODENAME}-security\";"
                ;;
            *)
                log_warn "Unknown distribution, using default Origins-Pattern"
                ;;
        esac

        sudo tee /etc/apt/apt.conf.d/52unattended-upgrades-local >/dev/null <<EOF
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Automatic-Reboot "false";
$( [ -n "$PATTERN" ] && printf 'Unattended-Upgrade::Origins-Pattern {\n  %s\n};\n' "$PATTERN" )
EOF
    else
        log_warn "/etc/os-release not found. Using default configuration."
    fi

    # Enable appropriate timers (Ubuntu uses apt-daily*, Debian may use unattended-upgrades.timer)
    log_info "Enabling automatic upgrade timers..."
    if sudo systemctl list-unit-files | grep -q '^apt-daily\.timer'; then
        sudo systemctl enable --now apt-daily.timer apt-daily-upgrade.timer || log_warn "Failed to enable apt-daily timers"
    elif sudo systemctl list-unit-files | grep -q '^unattended-upgrades\.timer'; then
        sudo systemctl enable --now unattended-upgrades.timer || log_warn "Failed to enable unattended-upgrades timer"
    else
        log_warn "No known upgrade timers found. Manual configuration may be required."
    fi

    # Trigger immediate run (optional, non-blocking)
    sudo systemctl start unattended-upgrades.service 2>/dev/null || true

    log_info "unattended-upgrades is configured. Verify with: systemctl list-timers | grep -E 'apt|unattended'"
}

install_systemd_templates() {
    local src_dir="./etc/systemd/system"
    if [[ ! -d "$src_dir" ]]; then
        log_warn "Directory $src_dir not found. Skipping unit installation."
        return 0
    fi

    log_info "Copying systemd units from $src_dir to /etc/systemd/system ..."
    sudo cp -f "$src_dir"/* /etc/systemd/system/ 2>/dev/null || true
    sudo systemctl daemon-reload

    # Enable and start all timers from the directory
    shopt -s nullglob
    local timer
    for timer in "$src_dir"/*.timer; do
        local unit
        unit=$(basename "$timer")
        log_info "Enabling and starting timer: $unit"
        sudo systemctl enable --now "$unit" || log_warn "Failed to enable $unit"
    done
    shopt -u nullglob

    log_info "Systemd units installation finished."
}

initial_setup() {
    # 1) User check
    if ! ensure_non_root_user_or_create; then
        return 1
    fi

    # 2) unattended-upgrades
    setup_unattended_upgrades

    # 3) systemd templates
    install_systemd_templates

    return 0
}
