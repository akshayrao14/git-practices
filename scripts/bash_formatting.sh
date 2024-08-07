#!/bin/bash

BLACK=$(tput setaf 40)
YELLOW=$(tput setaf 3)
WHITE_BOLD=$(tput setaf 7 bold)
BLUE_UNDL=$(tput setaf 4 smul)
CYAN_BLINK=$(tput setaf 6 blink)
CYAN_BOLD=$(tput setaf 6 bold)
CYAN=$(tput setaf 14)
LIGHT_GREEN=$(tput setaf 10)
LIGHT_RED=$(tput setaf 9)

SAMPLE_TEXT='\033[0;33m'
BOLD_TEXT='\033[1;33m'
LOW_INTENSITY_TEXT=$(tput setaf 3)
UNDERLINE_TEXT='\033[4;33m'
BLINKING_TEXT='\033[5;33m'
INVISIBLE_TEXT='\033[8;33m'
STRIKETHROUGH_TEXT='\033[9;33m'

RESET_FORMATTING() {
	tput sgr0
}