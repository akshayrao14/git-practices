#!/bin/bash

BLACK=$(tput setaf 40)
YELLOW=$(tput setaf 3)
WHITE_BOLD=$(tput setaf 7 bold)
BLUE_UNDL=$(tput setaf 4 smul)
BLUE_ITAL=$(tput setaf 4 sitm)
CYAN_BLINK=$(tput setaf 6 blink)
CYAN_BOLD=$(tput setaf 6 bold)
CYAN=$(tput setaf 14)
LIGHT_GREEN=$(tput setaf 10)
LIGHT_RED=$(tput setaf 9)
LOW_INTENSITY_TEXT=$(tput setaf 3)
LOW_INTENSITY_TEXT_DIM=$(tput setaf 3 dim)

# tput formatter
LINE_CLR=$(tput cr el) # clears the current line and goes to the beginning

RESET_FORMATTING() {
	tput sgr0
}