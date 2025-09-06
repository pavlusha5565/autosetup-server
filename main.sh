#!/bin/bash

#################################################
# AUTOSETUP - Automated Server Setup Script
# Version: 0.2
#################################################

# Strict mode bash
set -euo pipefail

# Load utility functions and modules
source ./modules/utils.sh
source ./modules/ssh.sh
source ./modules/firewall.sh
source ./modules/squid.sh
source ./modules/docker.sh
source ./modules/checkpoints.sh

init_autosetup_trap

#################################################
# MAIN EXECUTION
#################################################

# Error handling
set -e

# Check that script is run as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run the script as root"
    exit 1
fi

log_info "Welcome to the automated server setup script!"
log_info "Please provide the following configuration options:"
echo

#################################################
# COLLECTING CONFIGURATIONS
#################################################

# SSH Configuration
INSTALL_SSH=$(confirm "Do you want to install and configure ssh?")
if [[ "$INSTALL_SSH" == "y" ]]; then
  SSH_PORT=$(get_input "Enter SSH port" "22")
  GENERATE_SSH_KEYS=$(confirm "Do you want to generate a new pair of SSH keys?")
fi

# Firewall Configuration
INSTALL_NFTABLES=$(confirm "Do you want to install and configure nftables?")
INSTALL_FAIL2BAN=$(confirm "Do you want to install and configure Fail2Ban?")

# Squid Configuration
INSTALL_SQUID=$(confirm "Do you want to install and configure Squid proxy?")
if [[ "$INSTALL_SQUID" == "y" ]]; then
    PROXY_USER=$(get_input "Enter username for proxy access" "proxy_user")

    while true; do
        PROXY_PASS=$(get_hidden_input "Enter password for user $PROXY_USER" "change_me")
        log_info "Repeat the password for confirmation."
        PROXY_PASS_CONFIRM=$(get_hidden_input "Repeat password for user $PROXY_USER" "change_me")
        if [[ "$PROXY_PASS" == "$PROXY_PASS_CONFIRM" ]]; then
            break
        else
            log_error "Passwords do not match. Try again."
        fi
    done
fi

# Docker Configuration
INSTALL_DOCKER=$(confirm "Do you want to install Docker?")

#################################################
# CONFIRMATION OF CONFIGURATIONS
#################################################

# Summary of actions to perform
echo
log_info "The following actions will be performed:"
echo

i=1
log_info "$((i++)). Configure SSH on port $SSH_PORT"
[[ "$GENERATE_SSH_KEYS" == "y" ]] && log_info "$((i++)). Generate new SSH keys"
[[ "$INSTALL_NFTABLES" == "y" ]] && log_info "$((i++)). Install and configure nftables firewall"
[[ "$INSTALL_FAIL2BAN" == "y" ]] && log_info "$((i++)). Install and configure Fail2Ban"
[[ "$INSTALL_SQUID" == "y" ]] && log_info "$((i++)). Install and configure Squid proxy with user $PROXY_USER"
[[ "$INSTALL_DOCKER" == "y" ]] && log_info "$((i++)). Install Docker"
echo

# Final confirmation
PROCEED=$(confirm "Do you want to proceed with the setup?")
if [[ "$PROCEED" != "y" ]]; then
    log_info "Setup canceled by user. Exiting."
    exit 0
fi

#################################################
# EXECUTION OF CONFIGURATIONS
#################################################

log_info "***************************************************"
log_info "Setting up SSH..."
run_with_checkpoint "ssh_configured" call_if_enabled "$INSTALL_SSH" configure_ssh
run_with_checkpoint "ssh_keys_generated" call_if_enabled "$GENERATE_SSH_KEYS" generate_ssh_keys

log_info "***************************************************"
log_info "Setting up firewalls..."
run_with_checkpoint "nftables_configured" call_if_enabled "$INSTALL_NFTABLES" configure_nftables
run_with_checkpoint "fail2ban_configured" call_if_enabled "$INSTALL_FAIL2BAN" configure_fail2ban
run_with_checkpoint "ufw_configured" call_if_enabled "$INSTALL_NFTABLES" configure_ufw

log_info "***************************************************"
log_info "Setting up Squid proxy..."
run_with_checkpoint "squid_configured" call_if_enabled "$INSTALL_SQUID" configure_squid

log_info "***************************************************"
log_info "Setting up Docker..."
run_with_checkpoint "docker_configured" call_if_enabled "$INSTALL_DOCKER" configure_docker

#################################################
# FINALIZATION
#################################################

log_info "***************************************************"
log_info "Server setup completed successfully!"
log_info "Remember to verify that all services are working as expected."
