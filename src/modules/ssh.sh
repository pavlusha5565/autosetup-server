#!/bin/bash

# SSH Configuration Module
configure_ssh() {
    log_info "Configuring SSH..."

    # Copy the SSH configuration
    sudo cp ./etc/ssh/sshd_config /etc/ssh/sshd_config

    # Set the SSH port
    log_info "Changing port to $SSH_PORT..."
    sudo sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config

    log_warn "IMPORTANT: Password authentication is disabled in SSH configuration (PasswordAuthentication no)."
    log_warn "Before closing the session, make sure you have working key access!"

    systemctl_command restart ssh
}

# SSH Key Generation Module
generate_ssh_keys() {
    local ssh_key_name
    ssh_key_name="id_ed25519_$(date +%Y%m%d)"
    local ssh_dir="/root/.ssh"
    local ssh_key_path="$ssh_dir/$ssh_key_name"

    log_info "Generating SSH keys in $ssh_key_path..."

    sudo mkdir -p "$ssh_dir"

    sudo ssh-keygen -t ed25519 -f "$ssh_key_path"

    sudo bash -c "cat $ssh_key_path.pub >> $ssh_dir/authorized_keys"
    sudo chmod 700 "$ssh_dir"
    sudo chmod 600 "$ssh_dir/authorized_keys"

    if ! command_exists curl; then
        install_packages curl
    fi

    SERVER_IP=$(get_server_ip)

    log_info "SSH keys successfully generated!"
    log_info "------------------------------------------------------------"
    log_info "Private key is located on the server: $ssh_key_path"
    log_info "MAKE SURE to download the private key to your local computer with command:"
    log_info "scp -P $SSH_PORT root@$SERVER_IP:$ssh_key_path ~/.ssh/"
    log_info ""
    log_info "After downloading the key to your local computer, run:"
    log_info "chmod 600 ~/.ssh/$ssh_key_name"
    log_info ""
    log_info "To connect to the server, use the command:"
    log_info "ssh -i ~/.ssh/$ssh_key_name -p $SSH_PORT root@$SERVER_IP"
    log_info "------------------------------------------------------------"
    log_warn "After downloading the private key, you have to DELETE it from the server!!!"
}
