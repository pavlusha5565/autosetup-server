#!/bin/bash

# console.sh - Utility functions for colored console output and interactive selection.
# Provides message formatting and interactive multi-choice selection for shell scripts.
# Usage: Source this file and call provided functions in your scripts.

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print informational message in blue
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success message in green
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print warning message in yellow
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print error message in red
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print header in bold cyan
print_header() {
    echo -e "\n${BOLD}${CYAN}$1${NC}\n"
}

# Print highlighted text in magenta
print_highlight() {
    echo -e "${MAGENTA}$1${NC}"
}

# Show progress bar in console
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local bar
    local space

    local percent=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))

    bar=$(printf "%${completed}s" | tr ' ' '#')
    space=$(printf "%${remaining}s")

    echo -ne "\r[${bar}${space}] ${percent}% "

    if [ "$current" -eq "$total" ]; then
        echo -e "\n"
    fi
}

# Clear the current line in console
clear_line() {
    echo -ne "\r\033[K"
}

# Pause the script and wait for user input
pause() {
    local message=${1:-"Press any key to continue..."}
    read -n 1 -s -r -p "$message"
    echo
}

# Arrow key menu for single selection
arrow_menu() {
    local title="$1"
    local options=("${@:2}")
    local selected=0
    local key

    tput civis

    trap 'tput cnorm; echo; exit 1' INT

    while true; do
        clear_line
        for i in $(seq 1 $((${#options[@]} + 2))); do
            clear_line
            echo -ne "\033[A"
        done

        echo -e "${BOLD}${title}${NC}"

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -e " ${GREEN}➤${NC} ${BOLD}${options[$i]}${NC}"
            else
                echo -e "   ${options[$i]}"
            fi
        done

        IFS= read -rsn3 key

        case "$key" in
            $'\x1b[A') # Up arrow
                if [ "$selected" -gt 0 ]; then
                    selected=$((selected - 1))
                fi
                ;;
            $'\x1b[B') # Down arrow
                if [ "$selected" -lt $((${#options[@]} - 1)) ]; then
                    selected=$((selected + 1))
                fi
                ;;
            "") # Enter
                tput cnorm # Show cursor
                trap - INT # Remove signal handler
                return $selected
                ;;
        esac
    done
}

# Checkbox menu for multi-selection
checkbox_menu() {
    local title="$1"
    local options=("${@:2}")
    local selected=0
    local checked=()
    local key

    # Initialize checked array
    for i in "${!options[@]}"; do
        checked[$i]=0
    done

    tput civis

    trap 'tput cnorm; echo; exit 1' INT

    while true; do
        clear_line
        for i in $(seq 1 $((${#options[@]} + 3))); do
            clear_line
            echo -ne "\033[A"  >&2
        done

        echo -e "${BOLD}${title}${NC}"  >&2

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                echo -ne " ${GREEN}➤${NC} "  >&2
            else
                echo -ne "   "  >&2
            fi

            if [ "${checked[$i]}" -eq 1 ]; then
                echo -e "[${GREEN}✓${NC}] ${options[$i]}"  >&2
            else
                echo -e "[ ] ${options[$i]}"  >&2
            fi
        done

        echo -e "\n Press ${BOLD}Space${NC} to select, ${BOLD}Enter${NC} to confirm"  >&2

        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 rest
            key+=$rest
        fi

        case "$key" in
            $'\x1b[A') # Up arrow
                if [ "$selected" -gt 0 ]; then
                    selected=$((selected - 1))
                fi
                ;;
            $'\x1b[B') # Down arrow
                if [ "$selected" -lt $((${#options[@]} - 1)) ]; then
                    selected=$((selected + 1))
                fi
                ;;
            $'\x20') # Space
                if [ "${checked[$selected]}" -eq 0 ]; then
                    checked[$selected]=1
                else
                    checked[$selected]=0
                fi
                ;;
            ""|$'\n'|$'\r') # Enter (empty string or newline)
                tput cnorm # Show cursor
                trap - INT # Remove signal handler

                # Build result as indices of selected options
                local result=""
                for i in "${!checked[@]}"; do
                    if [ "${checked[$i]}" -eq 1 ]; then
                        result+="$i "
                    fi
                done

                # Check if result is empty
                if [ -z "$result" ]; then
                    return 255 # Special code if nothing selected
                else
                    echo "$result"
                    return 0
                fi
                ;;
        esac
    done
}