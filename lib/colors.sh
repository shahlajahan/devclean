#!/bin/bash
# Color and terminal capability helpers.
# Colors are only enabled when stdout is a TTY and NO_COLOR is unset.

_devclean_colors_enabled=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _devclean_colors_enabled=1
fi

if [ "$_devclean_colors_enabled" -eq 1 ]; then
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[1;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_CYAN="\033[0;36m"
    COLOR_MAGENTA="\033[0;35m"
    COLOR_BOLD="\033[1m"
    COLOR_DIM="\033[2m"
    COLOR_RESET="\033[0m"
else
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_CYAN=""
    COLOR_MAGENTA=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_RESET=""
fi

logo() {
    printf '%b' "$COLOR_BLUE"
    echo "========================================="
    echo "                DEV CLEAN"
    echo "========================================="
    printf '%b' "$COLOR_RESET"
}
