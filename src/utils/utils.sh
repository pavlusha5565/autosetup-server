#!/bin/bash

confirm() {
    local prompt="$1"
    local response

    read -p "$prompt (y/n): " response
    echo "$response"
}

get_input() {
    local prompt="$1"
    local default="$2"
    local result

    read -p "$prompt (default $default): " result
    echo "${result:-$default}"
}

get_hidden_input() {
    local prompt="$1"
    local default="$2"
    local result

    read -s -p "$prompt (default $default): " result
    echo
    echo "${result:-$default}"
}

install_packages() {
    log_info "Installing packages: $*"
    sudo apt-get install -y "$@"
}

systemctl_command() {
    local action="$1"
    local service="$2"
    log_info "${action^}ing $service..."
    if ! systemctl list-units --full -all | grep -Fq "$service.service"; then
        log_warn "Service $service does not exist. Skipping..."
        return
    fi
    sudo systemctl "$action" "$service"
}

command_exists() {
    command -v "$1" &> /dev/null
}

get_server_ip() {
    if ! command_exists curl; then
        install_packages curl
    fi
    curl -s ifconfig.me
}

call_if_enabled() {
    local var_value="$1"
    local func_name="$2"
    if [[ "$var_value" == "y" ]]; then
        $func_name
    fi
}
