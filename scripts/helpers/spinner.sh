#!/bin/bash

spinner_pid=

function start_spinner {
    set +m
    echo -n "$1         "
    echo ""

    spin1=('  •     ' '   •    ' '    •   ' '     •  ' '      • ' '     •  ' '    •   ' '   •    ' '  •     ' ' •      ')
    spin2=(' ┤ ' ' ┘ ' ' ┴ ' ' └ ' ' ├ ' ' ┌ ' ' ┬ ' ' ┐ ')

    { while : ; do for X in "${spin2[@]}" ; do echo -en "\b\b\b\b\b\b\b\b$X" ; sleep 0.1 ; done ; done & } 2>/dev/null
    spinner_pid=$!
}

function stop_spinner {
    { kill -9 $spinner_pid && wait; } 2>/dev/null
    set -m
    echo -en "\033[2K\r"
}

# trap stop_spinner EXIT
# start_spinner "I'm thinking! "
# sleep 4
# stop_spinner


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