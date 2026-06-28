#!/bin/bash

# ZSH installation module

install_zsh() {
    local user="${SUDO_USER:-$(whoami)}"

    install_now=$(confirm "Install zsh shell?")
    if [[ "$install_now" != "y" ]]; then
        log_error "Skipping install zsh shell"
        return 1
    fi

    install_packages zsh curl

    install_ohmyzsh=$(confirm "Install ohmyzsh (plugin)?")

    if [[ "$install_ohmyzsh" != "y" ]]; then
        log_error "Skipping install ohmyzsh plugin"
        return 1
    fi

    sudo -u "$user" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}
