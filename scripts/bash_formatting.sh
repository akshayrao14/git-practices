#!/usr/bin/env bash

# Check if colors should be enabled (terminal, NO_COLOR not set, TERM not "dumb")
COLORS_ENABLED=0
if [ -t 1 ] && [ -z "${NO_COLOR}" ] && [ "${TERM}" != "dumb" ]; then
    # Check if tput is available and supports colors
    if command -v tput >/dev/null 2>&1; then
        COLORS_ENABLED=1
        # Use tput if available
        RESET_FORMATTING='\033[0m'
        BOLD='\033[1m'
        UNDERLINE='\033[4m'
        BLINK='\033[5m'
        
        # Text colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        MAGENTA='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[0;37m'
        
        # Background colors
        BG_RED='\033[41m'
        BG_GREEN='\033[42m'
        BG_YELLOW='\033[43m'
        
        # Special formats
        LOW_INTENSITY_TEXT='\033[2m'
        BLINK_RED='\033[5;31m'
        BLINK_GREEN='\033[5;32m'
        
        # Additional tput-based formats (kept for backward compatibility)
        BLACK='\033[0;30m'
        WHITE_BOLD='\033[1;37m'
        BLUE_UNDERLINE='\033[4;34m'
        CYAN_BLINK='\033[5;36m'
        CYAN_BOLD='\033[1;36m'
        LIGHT_GREEN='\033[1;32m'
        LIGHT_RED='\033[1;31m'
        LINE_CLR='\r\033[K'  # Clears the current line and goes to the beginning
    else
        # Fallback to ANSI escape codes if tput is not available
        COLORS_ENABLED=1
        RESET_FORMATTING='\033[0m'
        BOLD='\033[1m'
        UNDERLINE='\033[4m'
        BLINK='\033[5m'
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        MAGENTA='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[0;37m'
        BG_RED='\033[41m'
        BG_GREEN='\033[42m'
        BG_YELLOW='\033[43m'
        LOW_INTENSITY_TEXT='\033[2m'
        BLINK_RED='\033[5;31m'
        BLINK_GREEN='\033[5;32m'
        LINE_CLR='\r\033[K'
    fi
fi

# Function to reset all text attributes
RESET_FORMATTING() {
    printf '%b' "${RESET_FORMATTING}"
}

# Export all variables
export COLORS_ENABLED

export RESET_FORMATTING BOLD UNDERLINE BLINK \
RED GREEN YELLOW BLUE MAGENTA CYAN WHITE \
BG_RED BG_GREEN BG_YELLOW \
LOW_INTENSITY_TEXT BLINK_RED BLINK_GREEN \
BLACK WHITE_BOLD BLUE_UNDERLINE CYAN_BLINK \
CYAN_BOLD LIGHT_GREEN LIGHT_RED LINE_CLR

# If sourced, return success
true
export BLUE_ITAL
export CYAN_BLINK
export CYAN_BOLD
export CYAN
export LIGHT_GREEN
export LIGHT_RED
export LOW_INTENSITY_TEXT
export LOW_INTENSITY_TEXT_DIM
export LINE_CLR
export RED_BLINK
export RESET_FORMATTING