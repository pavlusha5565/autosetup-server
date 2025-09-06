#!/bin/bash

CHECKPOINT_FILE=".autosetup_checkpoint"

function set_checkpoint() {
    echo "$1" >> "$CHECKPOINT_FILE"
}

function checkpoint_exists() {
    grep -q "^$1$" "$CHECKPOINT_FILE" 2>/dev/null
}

function autosetup_cleanup() {
    log_info "\n[!] Exit signal received. Cleaning up..."
    rm -f "$CHECKPOINT_FILE"
    log_info "[*] Cleanup done. Exiting."
    exit 1
}

function init_autosetup_trap() {
    trap autosetup_cleanup SIGINT SIGTERM
}

function run_with_checkpoint() {
    local checkpoint="$1"
    shift
    if checkpoint_exists "$checkpoint"; then
        return 0
    fi
    if "$@"; then
        set_checkpoint "$checkpoint"
        return 0
    else
        log_error "Error executing step: $checkpoint"
        exit 1
    fi
}
