#!/bin/bash
# iOS Simulator management via `xcrun simctl`.
#
# Safety model:
#  - A booted simulator is never deleted.
#  - DELETE (removes the device entirely) and ERASE (wipes content/settings
#    but keeps the device) are always kept as clearly distinct actions.
#  - Both require typing DELETE, since simulator data (test accounts, local
#    databases, provisioning) cannot be recovered once removed.

_SIM_NAME=()
_SIM_RUNTIME=()
_SIM_STATE=()
_SIM_UUID=()
_SIM_AVAILABLE=()

simulator_available() {
    command_exists xcrun && xcrun simctl help >/dev/null 2>&1
}

# Populates the _SIM_* parallel arrays from `xcrun simctl list devices`.
simulator_collect() {
    _SIM_NAME=()
    _SIM_RUNTIME=()
    _SIM_STATE=()
    _SIM_UUID=()
    _SIM_AVAILABLE=()

    simulator_available || return 1

    local runtime="" line
    while IFS= read -r line; do
        # simctl pads some lines with trailing whitespace; strip it so the
        # end-of-line anchors below match reliably.
        line="${line%"${line##*[![:space:]]}"}"
        if [[ "$line" =~ ^--\ (.+)\ --$ ]]; then
            runtime="${BASH_REMATCH[1]}"
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]{4}(.+)\ \(([0-9A-Fa-f-]+)\)\ \(([A-Za-z]+)\)(\ \(unavailable\))?$ ]]; then
            _SIM_NAME+=("${BASH_REMATCH[1]}")
            _SIM_UUID+=("${BASH_REMATCH[2]}")
            _SIM_STATE+=("${BASH_REMATCH[3]}")
            _SIM_RUNTIME+=("$runtime")
            if [ -n "${BASH_REMATCH[4]}" ]; then
                _SIM_AVAILABLE+=(0)
            else
                _SIM_AVAILABLE+=(1)
            fi
        fi
    done < <(xcrun simctl list devices 2>/dev/null)

    return 0
}

simulator_device_path() {
    printf '%s/%s' "$CORESIMULATOR_DEVICES_DIR" "$1"
}

simulator_devices_bytes() {
    path_size_bytes "$CORESIMULATOR_DEVICES_DIR"
}

simulator_caches_bytes() {
    path_size_bytes "$CORESIMULATOR_CACHES_DIR"
}

simulator_scan() {
    section_header "iOS Simulator"
    if ! simulator_available; then
        print_kv "Status:" "Xcode command line tools / simctl not found"
        return 0
    fi

    simulator_collect
    local count="${#_SIM_UUID[@]}"
    local booted=0
    local i
    for ((i = 0; i < count; i++)); do
        [ "${_SIM_STATE[$i]}" = "Booted" ] && booted=$((booted + 1))
    done

    print_kv "Devices:" "$count (booted: $booted)"
    print_kv "Devices data ($CORESIMULATOR_DEVICES_DIR):" "$(human_size "$(simulator_devices_bytes)")"
    print_kv "Simulator caches:" "$(human_size "$(simulator_caches_bytes)")"
}

simulator_list_table() {
    if ! simulator_available; then
        echo "xcrun simctl is not available. Install Xcode command line tools."
        return 1
    fi

    simulator_collect
    local count="${#_SIM_UUID[@]}"
    if [ "$count" -eq 0 ]; then
        echo "No simulator devices found."
        return 1
    fi

    printf ' %3s  %-24s %-14s %-10s %-9s %-36s\n' "#" "NAME" "RUNTIME" "STATE" "SIZE" "UUID"
    local i bytes avail_note
    for ((i = 0; i < count; i++)); do
        bytes="$(path_size_bytes "$(simulator_device_path "${_SIM_UUID[$i]}")")"
        avail_note=""
        [ "${_SIM_AVAILABLE[$i]}" -eq 0 ] && avail_note=" (unavailable)"
        printf ' %3d  %-24s %-14s %-10s %-9s %-36s%s\n' \
            "$((i + 1))" "${_SIM_NAME[$i]}" "${_SIM_RUNTIME[$i]}" "${_SIM_STATE[$i]}" \
            "$(human_size "$bytes")" "${_SIM_UUID[$i]}" "$avail_note"
    done
    return 0
}

simulator_delete_unavailable() {
    if ! simulator_available; then
        echo "xcrun simctl is not available."
        return 0
    fi

    echo "This runs: xcrun simctl delete unavailable"
    echo "It removes simulator devices whose runtime is no longer installed."
    echo "Their data (if any) is deleted and cannot be recovered."
    echo

    if confirm_delete_word "Delete all unavailable simulators?"; then
        run_or_dry "delete unavailable simulators" xcrun simctl delete unavailable
        log_action "deleted" "unavailable-simulators" 0
    else
        echo "Skipped."
    fi
}

simulator_delete_selected() {
    simulator_list_table || return 0
    echo
    printf 'Enter numbers to DELETE (space separated), or blank to cancel: '
    local sel
    read -r sel < /dev/tty 2>/dev/null || read -r sel
    [ -z "$sel" ] && { echo "Cancelled."; return 0; }

    local idx uuid name state bytes path
    for idx in $sel; do
        case "$idx" in
            ''|*[!0-9]*) echo "Skipping invalid selection: $idx"; continue ;;
        esac
        uuid="${_SIM_UUID[$((idx - 1))]:-}"
        [ -z "$uuid" ] && { echo "Skipping invalid selection: $idx"; continue; }
        name="${_SIM_NAME[$((idx - 1))]}"
        state="${_SIM_STATE[$((idx - 1))]}"

        if [ "$state" = "Booted" ]; then
            echo "Refusing to delete \"$name\" - it is currently Booted. Shut it down first."
            continue
        fi

        path="$(simulator_device_path "$uuid")"
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $name ($uuid)"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    The device and all its app data, permanently."
        echo "Effect:  The simulator disappears from Xcode's device list."
        echo "Action:  xcrun simctl delete $uuid"
        echo

        if confirm_delete_word "This permanently deletes the device."; then
            run_or_dry "delete simulator $name ($uuid)" xcrun simctl delete "$uuid"
            log_action "deleted" "$path" "$bytes"
        else
            echo "Skipped $name."
            log_action "skipped" "$path" "$bytes"
        fi
    done
}

simulator_erase_selected() {
    simulator_list_table || return 0
    echo
    echo "ERASE wipes a simulator's content and settings but keeps the device"
    echo "itself (it still appears in Xcode afterwards). This is different from"
    echo "DELETE, which removes the device entirely."
    echo
    printf 'Enter numbers to ERASE (space separated), or blank to cancel: '
    local sel
    read -r sel < /dev/tty 2>/dev/null || read -r sel
    [ -z "$sel" ] && { echo "Cancelled."; return 0; }

    local idx uuid name state bytes path
    for idx in $sel; do
        case "$idx" in
            ''|*[!0-9]*) echo "Skipping invalid selection: $idx"; continue ;;
        esac
        uuid="${_SIM_UUID[$((idx - 1))]:-}"
        [ -z "$uuid" ] && { echo "Skipping invalid selection: $idx"; continue; }
        name="${_SIM_NAME[$((idx - 1))]}"
        state="${_SIM_STATE[$((idx - 1))]}"

        if [ "$state" = "Booted" ]; then
            echo "Refusing to erase \"$name\" - it is currently Booted. Shut it down first."
            continue
        fi

        path="$(simulator_device_path "$uuid")"
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $name ($uuid)"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    All installed apps and app data on this simulator (device kept)."
        echo "Action:  xcrun simctl erase $uuid"
        echo

        if confirm_delete_word "This erases all content and settings on this device."; then
            run_or_dry "erase simulator $name ($uuid)" xcrun simctl erase "$uuid"
            log_action "erased" "$path" "$bytes"
        else
            echo "Skipped $name."
            log_action "skipped" "$path" "$bytes"
        fi
    done
}

simulator_shutdown_all() {
    if ! simulator_available; then
        echo "xcrun simctl is not available."
        return 0
    fi

    if confirm_yes_no "Shut down all booted simulators?"; then
        run_or_dry "shutdown all simulators" xcrun simctl shutdown all
    else
        echo "Skipped."
    fi
}

simulator_menu() {
    local choice
    while true; do
        section_header "Simulator cleanup"
        cat <<'EOF'
  1) List devices
  2) Delete unavailable devices
  3) Delete selected devices
  4) Erase selected devices (keep device, wipe content)
  5) Shut down all booted simulators
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) simulator_list_table ;;
            2) simulator_delete_unavailable ;;
            3) simulator_delete_selected ;;
            4) simulator_erase_selected ;;
            5) simulator_shutdown_all ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
