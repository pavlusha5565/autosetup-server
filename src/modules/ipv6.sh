#!/bin/bash

configure_ipv6() {
    for cmd in ip curl netplan; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command '$cmd' not found. Aborting."
            return 1
        fi
    done
    if ! sudo -n true 2>/dev/null; then
        log_error "Sudo privileges required. Aborting."
        return 1
    fi

    log_info "Setting up IPv6 configuration..."
    log_warn "Configuring network interface through netplan."

    iface=$(ip -o -4 route show to default | awk '{print $5}')
    if [ -z "$iface" ]; then
        iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E 'ens|eth|eno|enp|wlan' | head -n1)
    fi
    if [ -z "$iface" ]; then
        log_error "Could not detect network interface. Aborting."
        return 1
    fi
    log_info "Detected network interface: $iface"

    ext_ipv4=$(curl -s ifconfig.me)
    if [ -z "$ext_ipv4" ]; then
        log_warn "Could not detect external IPv4. Enter manually."
        ext_ipv4=""
    else
        log_info "External IPv4: $ext_ipv4"
    fi
    read -e -i "$ext_ipv4" -p "Enter external IPv4 (behind NAT, if applicable): " user_ipv4 || { log_error "Input cancelled."; return 1; }
    user_ipv4=${user_ipv4:-$ext_ipv4}

    # Определение маски IPv4
    ipv4_mask=$(ip -o -f inet addr show $iface | awk '{print $4}' | cut -d'/' -f2 | head -n1)
    ipv4_mask=${ipv4_mask:-24}

    # Получение IPv4 gateway
    gw_ipv4=$(ip route | grep default | awk '{print $3}')
    log_info "IPv4 gateway: $gw_ipv4"
    read -e -i "$gw_ipv4" -p "Enter IPv4 gateway: " user_gw_ipv4 || { log_error "Input cancelled."; return 1; }
    user_gw_ipv4=${user_gw_ipv4:-$gw_ipv4}

    # IPv6
    ipv6_needed=$(confirm "Do you need IPv6 support?")
    if [[ "$ipv6_needed" == "y" ]]; then
        ext_ipv6=$(curl -6 -s ifconfig.me)
        if [[ -z "$ext_ipv6" ]]; then
            log_warn "External IPv6 not detected. Enter manually."
            ext_ipv6=""
        else
            log_info "External IPv6: $ext_ipv6"
        fi
        read -e -i "$ext_ipv6" -p "Enter external IPv6: " user_ipv6 || { log_error "Input cancelled."; return 1; }
        user_ipv6=${user_ipv6:-$ext_ipv6}

        gw_ipv6=$(ip -6 route | grep default | awk '{print $3}')
        gw_ipv6=${gw_ipv6:-fe80::1}
        log_info "IPv6 gateway: $gw_ipv6"
        read -e -i "$gw_ipv6" -p "Enter IPv6 gateway: " user_gw_ipv6 || { log_error "Input cancelled."; return 1; }
        user_gw_ipv6=${user_gw_ipv6:-$gw_ipv6}
    else
        user_ipv6=""
        user_gw_ipv6=""
    fi

    netplan_file="/etc/netplan/01-netcfg.yaml"
    backup_file="/etc/netplan/01-netcfg.yaml.bak"
    if [ -f "$netplan_file" ]; then
        sudo cp "$netplan_file" "$backup_file"
        log_info "Backup of netplan config created: $backup_file"
    fi
    log_info "Generating netplan config: $netplan_file"

    netplan_content="network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    $iface:\n      addresses:\n        - $user_ipv4/$ipv4_mask"
    if [[ "$ipv6_needed" == "y" && -n "$user_ipv6" ]]; then
        netplan_content+="\n        - $user_ipv6/64"
    fi
    netplan_content+="\n      nameservers:\n        addresses:\n          - 8.8.8.8\n          - 2001:4860:4860::8888\n      routes:\n        - to: default\n          via: $user_gw_ipv4\n          on-link: true"
    if [[ "$ipv6_needed" == "y" && -n "$user_gw_ipv6" ]]; then
        netplan_content+="\n        - to: ::/0\n          via: $user_gw_ipv6\n          on-link: true"
    fi

    echo -e "$netplan_content" | sudo tee "$netplan_file" > /dev/null

    log_info "Trying to apply netplan configuration..."
    if sudo netplan try --timeout 30; then
        sudo netplan apply
        log_info "Netplan configuration applied successfully!"
        return 0
    else
        log_error "Failed to apply netplan configuration. Restoring backup."
        if [ -f "$backup_file" ]; then
            sudo cp "$backup_file" "$netplan_file"
            sudo netplan apply
            log_warn "Netplan config restored from backup."
        fi
        return 1
    fi
}
