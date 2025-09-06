#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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

restart_service() {
    local service="$1"
    log_info "Restarting $service..."
    sudo systemctl restart "$service"
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
