#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SSH_USER=root

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

set -e

# Check that script is run as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run the script as root"
    exit 1
fi

# 1. Set up ssh
read -p "Enter SSH port (default 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

log_info "Copying sshd_config..."
sudo cp ./etc/ssh/sshd_config /etc/ssh/sshd_config

log_info "Changing port to $SSH_PORT..."
sudo sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config

log_warn "IMPORTANT: Password authentication is disabled in SSH configuration (PasswordAuthentication no)."
log_warn "Before closing the session, make sure you have working key access!"

# 2. Generate SSH keys
log_warn "Do you want to generate a new pair of SSH keys? (y/n)"
read -r generate_keys
if [[ "$generate_keys" == "y" ]]; then
    # Create a unique key name with hostname and date
    SSH_KEY_NAME="id_ed25519_$(date +%Y%m%d)"
    SSH_DIR="/root/.ssh"
    
    SSH_KEY_PATH="$SSH_DIR/$SSH_KEY_NAME"
    log_info "Generating SSH keys in $SSH_KEY_PATH..."
    
    # Create .ssh directory if it doesn't exist
    sudo mkdir -p "$SSH_DIR"
    
    # Generate keys (using the more modern ed25519)
    sudo ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
    
    # Add the public key to authorized_keys
    sudo bash -c "cat $SSH_KEY_PATH.pub >> $SSH_DIR/authorized_keys"
    sudo chmod 700 "$SSH_DIR"
    sudo chmod 600 "$SSH_DIR/authorized_keys"
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl
    fi
    
    # Get IP address
    SERVER_IP=$(curl -s ifconfig.me)
    
    log_info "SSH keys successfully generated!"
    log_info "------------------------------------------------------------"
    log_info "Private key is located on the server: $SSH_KEY_PATH"
    log_info "MAKE SURE to download the private key to your local computer with command:"
    log_info "scp -P $SSH_PORT root@$SERVER_IP:$SSH_KEY_PATH ~/.ssh/"
    log_info ""
    log_info "After downloading the key to your local computer, run:"
    log_info "chmod 600 ~/.ssh/$SSH_KEY_NAME"
    log_info ""
    log_info "To connect to the server, use the command:"
    log_info "ssh -i ~/.ssh/$SSH_KEY_NAME -p $SSH_PORT root@$SERVER_IP"
    log_info "------------------------------------------------------------"
    log_warn "SAVE THIS INFORMATION! After server reboot, password login will be unavailable."
else
    log_warn "Skipping SSH key generation."
    log_warn "Make sure you already have configured key access, otherwise you will lose access to the server!"
fi


log_info "Restarting ssh..."
sudo systemctl restart ssh

# Check if nftables is installed
if ! command -v nft &> /dev/null; then
    log_warn "nft is not installed. Install and switch the server to nftables? (y/n)"
    read -r answer
    if [[ "$answer" == "y" ]]; then
        log_info "Installing nftables..."
        sudo apt update
        sudo apt install -y nftables
        log_info "Enabling nftables..."
        sudo systemctl enable nftables
        sudo systemctl start nftables
    else
        log_warn "Skipping nftables installation. Fail2ban will not work with iptables, manual configuration will be required."
    fi
else
    log_info "nft is already installed."
fi

log_info "***************************************************"

# Install fail2ban
log_info "Installing fail2ban..."
sudo apt install -y fail2ban

log_info "Copying fail2ban config..."
sudo cp -r ./etc/fail2ban/* /etc/fail2ban/

log_info "Restarting fail2ban..."
sudo systemctl restart fail2ban

log_info "***************************************************"

# Install ufw
log_info "Installing ufw..."
sudo apt install -y ufw
log_info "Denying incoming connections..."
sudo ufw default deny incoming
log_info "Allowing outgoing connections..."
sudo ufw default allow outgoing
log_info "Opening port $SSH_PORT for SSH..."
sudo ufw allow ${SSH_PORT}/tcp

# Enable ufw
log_info "Enabling ufw..."
sudo ufw --force enable
log_info "Before closing the session, make sure you can connect via SSH. Otherwise, you may lose access to the server!"
log_info "Current ufw status:"
sudo ufw status verbose
log_info "Waiting for confirmation that you can connect via SSH. Otherwise press Ctrl+C to interrupt the script. After that, type sudo ufw disable to disable ufw."
log_info "Press Enter to continue..."
read -r confirm

log_info "***************************************************"

# Install squid
if ! command -v squid &> /dev/null; then
    log_warn "Squid is not installed. Install? (y/n)"
    read -r answer
    if [[ "$answer" == "y" ]]; then
        log_info "Installing Squid..."
        sudo apt-get update
        sudo apt-get install -y squid apache2-utils

        log_info "Copying squid config..."
        sudo cp ./etc/squid/squid.conf /etc/squid/squid.conf
        SERVER_IP=$(curl -s ifconfig.me)
        log_info "Setting IP address $SERVER_IP in squid config..."
        sudo sed -i "s/^acl localnet src .*/acl localnet src ${SERVER_IP}\/32/" /etc/squid/squid.conf

        log_info "Creating password file for squid..."
        log_info "Enter username for proxy access:"
        read -r proxy_user
        log_info "Enter password for user $proxy_user:"
        read -r proxy_pass
        sudo htpasswd -b /etc/squid/passwd "$proxy_user" "$proxy_pass"

        log_info "Restarting squid..."
        sudo systemctl restart squid
        log_info "Squid installed and configured!"

        log_info "Adding rule in ufw for port 3128..."
        sudo ufw allow 3128/tcp
        
        log_info "------------------------------------------------------------"
        log_info "To connect to the proxy use the following data:"
        log_info "Server IP address: $(curl -s ifconfig.me)"
        log_info "Port: 3128"
        log_info "Username: $proxy_user"
        log_info "Password: $proxy_pass"
        log_info "------------------------------------------------------------"
    else
        log_warn "Skipping Squid installation."
    fi
else
    log_info "Squid is already installed."
fi

log_info "***************************************************"

# Install docker
log_warn "Docker is not installed. Install? (y/n)"
read -r answer
if [[ "$answer" == "y" ]]; then
    log_info "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \\n  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \\n  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \\n  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
else
    log_warn "Skipping Docker installation."
fi

log_info "Setup completed!"

# Set up ipv6 configuration
log_warn "Set up ipv6 configuration? (y/n)"
read -r answer

if [[ "$answer" == "y" ]]; then
    log_info "Setting up ipv6 configuration..."
    # --- Setting up network interface through netplan ---
    log_warn "We will configure the network interface through netplan."
    # Get interface name
    iface=$(ip -o -4 route show to default | awk '{print $5}')
    if [ -z "$iface" ]; then
            iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'ens|eth' | head -n1)
    fi
    log_info "Detected network interface: $iface"

    # Get external IPv4
    ext_ipv4=$(curl -s ifconfig.me)
    log_info "External IPv4: $ext_ipv4"
    read -e -i "$ext_ipv4" -p "Enter external IPv4 (behind NAT, if applicable): " user_ipv4
    user_ipv4=${user_ipv4:-$ext_ipv4}

    # Ask about IPv6
    read -p "Do you need IPv6 support? (y/n): " ipv6_needed
    if [[ "$ipv6_needed" == "y" ]]; then
            ext_ipv6=$(curl -6 -s ifconfig.me)
            if [[ -z "$ext_ipv6" ]]; then
                    log_warn "External IPv6 not detected. Enter manually."
            else
                    log_info "External IPv6: $ext_ipv6"
            fi
            read -e -i "$ext_ipv6" -p "Enter external IPv6: " user_ipv6
            user_ipv6=${user_ipv6:-$ext_ipv6}
    else
            user_ipv6=""
    fi

    # Get IPv4 gateway
    gw_ipv4=$(ip route | grep default | awk '{print $3}')
    log_info "IPv4 gateway: $gw_ipv4"
    read -e -i "$gw_ipv4" -p "Enter IPv4 gateway: " user_gw_ipv4
    user_gw_ipv4=${user_gw_ipv4:-$gw_ipv4}

    # Get IPv6 gateway (link-local)
    gw_ipv6=$(ip -6 route | grep default | awk '{print $3}')
    if [[ -z "$gw_ipv6" ]]; then
            gw_ipv6="fe80::1"
    fi
    if [[ "$ipv6_needed" == "y" ]]; then
            log_info "IPv6 gateway: $gw_ipv6"
            read -e -i "$gw_ipv6" -p "Enter IPv6 gateway: " user_gw_ipv6
            user_gw_ipv6=${user_gw_ipv6:-$gw_ipv6}
    fi

    # Generate netplan config
    netplan_file="/etc/netplan/01-netcfg.yaml"
    log_info "Generating netplan config: $netplan_file"
    sudo bash -c "cat > $netplan_file <<EOF
    network:
        version: 2
        renderer: networkd
        ethernets:
            $iface:
                addresses:
                    - $user_ipv4/24
    $( [[ "$ipv6_needed" == "y" && -n "$user_ipv6" ]] && echo "        - $user_ipv6/64" )
                nameservers:
                    addresses:
                        - 8.8.8.8
                        - 2001:4860:4860::8888
                routes:
                    - to: default
                        via: $user_gw_ipv4
                        on-link: true
    $( [[ "$ipv6_needed" == "y" && -n "$user_gw_ipv6" ]] && echo "        - to: \"::/0\"\n          via: \"$user_gw_ipv6\"\n          on-link: true" )
    EOF"

    log_info "Trying to apply netplan..."
    sudo netplan try
    sudo netplan apply
    log_info "Netplan applied!"
else
    log_warn "Skipping ipv6 configuration."
fi
