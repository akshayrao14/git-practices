#!/bin/bash

# Source colors and formatting if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/../bash_formatting.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../bash_formatting.sh"
else
    # Fallback formatting
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Function to check if script is in PATH and suggest adding it if not
check_script_in_path() {
    local script_name="$1"
    local script_path="$(realpath "$0")"
    local script_dir="$(dirname "$script_path")"
    
    # Check if script is in PATH
    if ! command -v "$script_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}Note:${NC} The script is not in your PATH. For easier access, add the following to your shell configuration file:"
        echo -e "\n${BLUE}# Add to ~/.bashrc, ~/.zshrc, or your shell's equivalent${NC}"
        echo -e "export PATH=\"$script_dir:\$PATH\""
        echo -e "\nThen run: source ~/.bashrc  # or your shell's config file"
        echo -e "\nOr create a symlink in a directory that's already in your PATH:"
        echo -e "ln -s \"$script_path\" ~/.local/bin/$script_name"
        echo -e "\nAfter adding to PATH, you can simply run: ${GREEN}$script_name${NC}"
        echo -e "${YELLOW}Note:${NC} You may need to create ~/.local/bin if it doesn't exist and log out/in for changes to take effect.\n"
        return 1
    fi
    return 0
}

# Function to get the directory where this script is located
get_script_dir() {
    # Get the directory of the currently executing script
    # Works with symlinks and different ways of calling the script
    local SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        local DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    echo "$(cd -P "$(dirname "$SOURCE")" && pwd)"
}
