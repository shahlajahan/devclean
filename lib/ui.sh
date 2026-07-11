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
  report      Generate a timestamped TXT, JSON, and Markdown report
  update      Check GitHub for a newer release (read-only, never auto-updates)

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
    # menu_header <cached_recoverable_bytes>
    # Disk free is a cheap `df` call and safe to refresh every redraw.
    # The reclaimable estimate is many `du` calls across every category
    # (several seconds, more since v1.1.0 added Simulator/AVD to it) - the
    # caller computes it once and passes it in, refreshing only after an
    # action that could actually have changed disk usage, instead of
    # recomputing it on every single menu redraw.
    local recoverable="${1:-0}"
    clear 2>/dev/null || true
    logo
    echo
    echo "DEV CLEAN v${DEVCLEAN_VERSION}"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '%b(DRY-RUN MODE - nothing will be deleted)%b\n' "$COLOR_CYAN" "$COLOR_RESET"
    fi
    echo
    local free
    free="$(disk_free_bytes)"
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
 12) Bun cleanup
  0) Exit
EOF
}

main_menu() {
    local choice recoverable
    recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"
    while true; do
        menu_header "$recoverable"
        menu_options
        echo
        printf '%bSelect an option: %b' "$COLOR_BOLD" "$COLOR_RESET"
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        echo
        case "$choice" in
            1) scan_command; press_enter_to_continue ;;
            2) quick_clean_run; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            3) xcode_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            4) simulator_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            5) android_gradle_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            6) flutter_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            7) node_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            8) docker_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            9) whatsapp_menu; press_enter_to_continue ;;
            10) doctor_command; press_enter_to_continue ;;
            11) report_command; press_enter_to_continue ;;
            12) bun_menu; recoverable="$(estimate_reclaimable_bytes 2>/dev/null)"; press_enter_to_continue ;;
            0) echo "Goodbye."; break ;;
            "") ;;
            *) echo "Unknown option: $choice"; press_enter_to_continue ;;
        esac
    done
}

# progress_bar <current> <total> <label>
# One plain ASCII line per call, e.g. "Scanning: Xcode [#####...........]  25%".
# No external dependencies, no carriage-return redraw (each step already
# prints multi-line section output right after, so a static line per step
# is simpler and stays readable in redirected output/logs).
progress_bar() {
    local current="$1" total="${2:-1}" label="$3"
    [ "$total" -le 0 ] && total=1
    local pct=$(( current * 100 / total ))
    local width=20
    local filled=$(( pct * width / 100 ))
    local i bar=""
    for ((i = 0; i < width; i++)); do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}#"
        else
            bar="${bar}."
        fi
    done
    printf '%b%s [%s] %3d%%%b\n' "$COLOR_DIM" "$label" "$bar" "$pct" "$COLOR_RESET"
}

# multi_select_prompt <title> <label...>
# Generic checkbox-style picker: toggle numbers, 'a'/'n' for all/none,
# 'c' to confirm, 'q' to cancel. Prints the final space-separated list of
# selected 1-based indices on success; prints nothing and returns 1 on
# cancel. Plain numbered input only, matching every other menu in this
# tool - no arrow-key/ncurses dependency.
multi_select_prompt() {
    local title="$1"
    shift
    local -a labels=("$@")
    local n=${#labels[@]}
    local -a selected
    local i
    for ((i = 0; i < n; i++)); do
        selected[i]=0
    done

    # The interactive display goes to stderr, not stdout: callers capture
    # this function's stdout via command substitution to get the final
    # selection, so stdout must carry only that result - never the menu.
    local input tok idx
    while true; do
        {
            section_header "$title"
            for ((i = 0; i < n; i++)); do
                if [ "${selected[i]}" -eq 1 ]; then
                    printf '  [%bx%b] %2d) %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$((i + 1))" "${labels[i]}"
                else
                    printf '  [ ] %2d) %s\n' "$((i + 1))" "${labels[i]}"
                fi
            done
            echo
            echo "Numbers to toggle (space separated) - 'a' all, 'n' none, 'c' confirm, 'q' cancel"
            printf 'Select: '
        } >&2
        read -r input < /dev/tty 2>/dev/null || read -r input

        case "$input" in
            q|Q)
                return 1
                ;;
            c|C)
                break
                ;;
            a|A)
                for ((i = 0; i < n; i++)); do selected[i]=1; done
                ;;
            n|N)
                for ((i = 0; i < n; i++)); do selected[i]=0; done
                ;;
            *)
                for tok in $input; do
                    case "$tok" in
                        ''|*[!0-9]*) continue ;;
                    esac
                    idx=$((tok - 1))
                    if [ "$idx" -ge 0 ] && [ "$idx" -lt "$n" ]; then
                        if [ "${selected[idx]}" -eq 1 ]; then
                            selected[idx]=0
                        else
                            selected[idx]=1
                        fi
                    fi
                done
                ;;
        esac
    done

    local out=""
    for ((i = 0; i < n; i++)); do
        [ "${selected[i]}" -eq 1 ] && out="$out $((i + 1))"
    done
    printf '%s' "$out"
    return 0
}
