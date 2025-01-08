#!/bin/bash

spinner_pid=
spinner_sleep=0.1 # in seconds

function start_spinner {
    set +m
    echo -n "$1         "
    echo ""
    tput civis # cursor invisible
    
    finalSpinner=( "${random_spinner[@]}" )
    
    { while : ; do for X in "${finalSpinner[@]}" ; do echo -en "\b\b\b\b\b\b\b\b$X" ; sleep $spinner_sleep ; done ; done & } 2>/dev/null
    spinner_pid=$!
}

# Kill the spinner, restore cursor visibility, and clear the line.
function stop_spinner {
    { kill -9 $spinner_pid && wait; } 2>/dev/null
    set -m
    tput cnorm # cursor visible
    echo -en "\033[2K\r"
}

# Prints $1 while running the function $2 with arguments ${@:3} and
# printing a spinner. Automatically kills the spinner on exit.
# returns the exit code of $2
run_with_spinner () {
    trap stop_spinner EXIT
    start_spinner "$1"
    
    ($2 "${@:3}") || { stop_spinner; return 1; }
    
    stop_spinner
    
    return 0
}

######  Random SPINNER selection  ########
no_of_spinners=5
# spinner_no="$(shuf -i 1-$no_of_spinners -n 1)" ## chooses randomly
spinner_no=$(( 10#$(date +%j) % "$no_of_spinners" + 1 )) ## changes spinner once a day

if [ "$spinner_no" -eq 1 ]; then
    random_spinner=('  •     ' '   •    ' '    •   ' '     •  ' '      • ' '     •  ' '    •   ' '   •    ' '  •     ' ' •      ')
    elif [ "$spinner_no" -eq 2 ]; then
    random_spinner=(' ┤ ' ' ┘ ' ' ┴ ' ' └ ' ' ├ ' ' ┌ ' ' ┬ ' ' ┐ ')
    elif [ "$spinner_no" -eq 3 ]; then
    random_spinner=(' ⠋ ' ' ⠙ ' ' ⠹ ' ' ⠸ ' ' ⠼ ' ' ⠴ ' ' ⠦ ' ' ⠧ ' ' ⠇ ' ' ⠏ ')
    elif [ "$spinner_no" -eq 4 ]; then
    random_spinner=('▰▱▱▱▱ ' '▰▰▱▱▱ ' '▰▰▰▱▱ ' '▱▰▰▰▱ ' '▱▱▰▰▰ ' '▱▱▱▰▰ ' '▱▱▱▱▰ ' '▱▱▱▱▱ ')
else
    random_spinner=('  😑  ' '  😕  ' '  🥺  ' '  🥱  ' '  🤨  ' '  🙄  ' '  😖  ' '  😡  ' '  😤  ' '  🤢  ' '  😱  ' '🖕😖 ' '  😖🖕 ' '🖕🤬🖕' )
    spinner_sleep=0.4
fi
