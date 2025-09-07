#!/bin/bash

# Squid Proxy Configuration Module
configure_squid() {
    log_info "Configuring Squid proxy server..."
    install_packages squid apache2-utils

    log_info "Copying squid config..."
    sudo cp ./etc/squid/squid.conf /etc/squid/squid.conf

    SERVER_IP=$(get_server_ip)
    log_info "Setting IP address $SERVER_IP in squid config..."
    sudo sed -i "s/^acl localnet src .*/acl localnet src ${SERVER_IP}\/32/" /etc/squid/squid.conf

    log_info "Creating password file for squid..."
    sudo htpasswd -b /etc/squid/passwd "$PROXY_USER" "$PROXY_PASS"

    systemctl_command restart squid

    log_info "------------------------------------------------------------"
    log_info "To connect to the proxy use the following data:"
    log_info "Server IP address: $SERVER_IP"
    log_info "Port: 3128"
    log_info "Username: $PROXY_USER"
    log_info "Password: $PROXY_PASS"
    log_info "------------------------------------------------------------"
}
