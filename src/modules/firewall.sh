#!/bin/bash

configure_nftables() {
    log_info "Configuring nftables firewall..."
    install_packages nftables

    log_info "Enabling nftables..."
    systemctl_command enable nftables
    systemctl_command start nftables
}

configure_ufw() {
    log_info "Configuring UFW firewall..."
    install_packages ufw

    log_info "Denying incoming connections..."
    sudo ufw default deny incoming

    log_info "Allowing outgoing connections..."
    sudo ufw default allow outgoing

    log_info "Opening port $SSH_PORT for SSH..."
    sudo ufw allow ${SSH_PORT}/tcp

    if [[ "$INSTALL_SQUID" == "y" ]]; then
        log_info "Adding rule in ufw for port 3128..."
        sudo ufw allow 3128/tcp
    fi

    log_info "Enabling ufw..."
    sudo ufw --force enable

    log_info "Current ufw status:"
    sudo ufw status verbose

    log_warn "Before closing the session, make sure you can connect via SSH. Otherwise, you may lose access to the server!"
    log_warn "Press Enter to continue or Ctrl+C to interrupt the script. After interruption, type sudo ufw disable to disable ufw."
    read -r
}

configure_fail2ban() {
    log_info "Configuring Fail2Ban..."
    install_packages fail2ban

    log_info "Copying fail2ban config..."
    sudo cp -r ./etc/fail2ban/* /etc/fail2ban/

    systemctl_command restart fail2ban
}
