#!/bin/bash

#################################################
# AUTOSETUP - Automated Server Setup Script
# Version: 0.4
#################################################

# Strict mode bash
#  set -euo pipefail

# Load utility functions and modules
source ./src/utils/console.sh
source ./src/utils/utils.sh
source ./src/modules/checkpoints.sh
source ./src/modules/bootstrap.sh
source ./src/modules/ssh.sh
source ./src/modules/firewall.sh
source ./src/modules/squid.sh
source ./src/modules/ipv6.sh
source ./src/modules/docker.sh

#################################################
# TRAP HANDLERS
#################################################

# Cleanup function called on script interruption
cleanup() {
    print_error "Script interrupted by user"
    exit 130
}

# Initialize trap handlers
trap cleanup SIGINT SIGTERM

#################################################
# FUNCTIONS
#################################################

# Execute SSH configuration function
run_initial_setup() {
    print_header "Initial System Setup"
    if initial_setup; then
        print_success "Initial system setup completed"
    else
        print_warning "Initial setup not completed. See messages above."
    fi
    pause
}

# Execute SSH configuration function
run_ssh_config() {
    print_header "SSH Configuration"
    ssh_port=$(get_input "Enter SSH port" "22")
    configure_ssh "$ssh_port"
    print_success "SSH configuration completed"
    sshKeys=$(confirm "Do you want to generate new SSH keys?")
    call_if_enabled "$sshKeys" run_ssh_keys_gen "$ssh_port"
    pause
}

# Execute SSH key generation function
run_ssh_keys_gen() {
    local ssh_port="$1"
    print_header "SSH Key Generation"
    generate_ssh_keys "$ssh_port"
    print_success "SSH key generation completed"
    pause
}

# Execute IPv6 configuration function
run_ipv6_config() {
    print_header "NOT WORKING"
    return 0;

    print_header "IPv6 Configuration"
    configure_ipv6
    print_success "IPv6 configuration completed"
    pause
}

# Execute nftables configuration function
run_nftables_config() {
    print_header "nftables Configuration"
    configure_nftables
    print_success "nftables configuration completed"
    pause
}

# Execute Fail2Ban configuration function
run_fail2ban_config() {
    print_header "Fail2Ban Configuration"
    configure_fail2ban
    print_success "Fail2Ban configuration completed"
    pause
}

# Execute UFW configuration function
run_ufw_config() {
    print_header "UFW Configuration"
    configure_ufw
    print_success "UFW configuration completed"
    pause
}

# Execute Squid proxy configuration function
run_squid_config() {
    print_header "Squid Proxy Configuration"
    configure_squid
    print_success "Squid proxy configuration completed"
    pause
}

# Execute Docker installation function
run_docker_install() {
    print_header "Docker Installation"
    configure_docker
    print_success "Docker installation completed"
    pause
}

#################################################
# MAIN EXECUTION
#################################################

# Check that script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run the script as root user"
    exit 1
fi

# Main loop for menu
while true; do
    clear
    print_header "Automated Server Setup"
    print_info "Please select an option to configure:"

    # Define menu options
    OPTIONS=(
        "Initial System Setup"
        "Configure SSH"
        "Configure IPv6"
        "Configure nftables"
        "Configure Fail2Ban"
        "Configure UFW"
        "Configure Squid Proxy"
        "Install Docker"
        "Exit"
    )

    # Call arrow menu function
    arrow_menu "Server Configuration Menu:" "${OPTIONS[@]}"
    CHOICE=$?

    # Process menu selection
    case $CHOICE in
        0) run_initial_setup ;;
        1) run_ssh_config ;;
        2) run_ipv6_config ;;
        3) run_nftables_config ;;
        4) run_fail2ban_config ;;
        5) run_ufw_config ;;
        6) run_squid_config ;;
        7) run_docker_install ;;
        8)
            print_info "Exiting the program..."
            exit 0
            ;;
    esac
done
