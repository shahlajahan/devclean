#!/bin/bash
# Interactive menu and top-level text UI.

show_version() {
    echo "devclean version ${DEVCLEAN_VERSION}"
}

show_help() {
    cat <<EOF
devclean ${DEVCLEAN_VERSION} - audit and safely clean developer disk usage on macOS

USAGE
  devclean [command] [options]

COMMANDS
  (none)      Open the interactive menu
  scan        Scan known developer locations and print a summary
  clean       Open the interactive safe-clean menu
  doctor      Check the health of your development environment
  report      Generate a timestamped TXT and JSON report

OPTIONS
  --dry-run   Never delete or modify anything; print what would happen
  --help      Show this help text
  --version   Show the version number

EXAMPLES
  devclean scan
  devclean --dry-run clean
  devclean doctor
  devclean report

Nothing is ever deleted without an explicit confirmation. High-impact
actions (simulators, DeviceSupport, Docker pruning, project build folders)
require typing DELETE. Low-risk cache cleanup accepts y/N.

Logs:    ${DEVCLEAN_HOME}/logs
Reports: ${DEVCLEAN_HOME}/reports
EOF
}

menu_header() {
    clear 2>/dev/null || true
    logo
    echo
    echo "DEV CLEAN v${DEVCLEAN_VERSION}"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '%b(DRY-RUN MODE - nothing will be deleted)%b\n' "$COLOR_CYAN" "$COLOR_RESET"
    fi
    echo
    local free recoverable
    free="$(disk_free_bytes)"
    recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"
    [ -z "$recoverable" ] && recoverable=0
    print_kv "Disk free:" "$(human_size "$free")"
    print_kv "Potentially recoverable:" "$(human_size "$recoverable")"
    echo
}

menu_options() {
    cat <<'EOF'
  1) Scan system
  2) Quick clean
  3) Xcode cleanup
  4) Simulator cleanup
  5) Android / Gradle cleanup
  6) Flutter cleanup
  7) Node cleanup
  8) Docker cleanup
  9) WhatsApp storage audit
 10) Developer doctor
 11) Generate report
  0) Exit
EOF
}

read_menu_choice() {
    local choice
    printf '%bSelect an option: %b' "$COLOR_BOLD" "$COLOR_RESET"
    read -r choice < /dev/tty 2>/dev/null || read -r choice
    printf '%s' "$choice"
}

main_menu() {
    local choice
    while true; do
        menu_header
        menu_options
        echo
        choice="$(read_menu_choice)"
        echo
        case "$choice" in
            1) scan_command; press_enter_to_continue ;;
            2) quick_clean_run; press_enter_to_continue ;;
            3) xcode_menu; press_enter_to_continue ;;
            4) simulator_menu; press_enter_to_continue ;;
            5) android_gradle_menu; press_enter_to_continue ;;
            6) flutter_menu; press_enter_to_continue ;;
            7) node_menu; press_enter_to_continue ;;
            8) docker_menu; press_enter_to_continue ;;
            9) whatsapp_menu; press_enter_to_continue ;;
            10) doctor_command; press_enter_to_continue ;;
            11) report_command; press_enter_to_continue ;;
            0) echo "Goodbye."; break ;;
            "") ;;
            *) echo "Unknown option: $choice"; press_enter_to_continue ;;
        esac
    done
}
