#!/bin/bash

# Initial system setup module

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
    sudo apt update && sudo apt upgrade -y

    # 1) unattended-upgrades
    setup_unattended_upgrades

    # 2) systemd templates
    install_systemd_templates

    return 0
}
