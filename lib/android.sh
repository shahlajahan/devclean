#!/bin/bash
# Android SDK / AVD cleanup.
#
# Safety model:
#  - The Android SDK install itself (~/Library/Android/sdk) is reported but
#    NEVER deleted by this tool - it is too large a blast radius to automate.
#  - AVDs (emulator images) can hold significant disk space; removing one is
#    high-impact and requires typing DELETE. A currently running AVD is
#    never touched.
#  - Project-level Android build caches are only touched inside an
#    explicitly selected project path.

android_sdk_bytes() {
    path_size_bytes "$ANDROID_HOME_DIR"
}

android_dot_dir_bytes() {
    path_size_bytes "$ANDROID_DOT_DIR"
}

android_avd_bytes() {
    path_size_bytes "$ANDROID_AVD_DIR"
}

android_scan() {
    section_header "Android"
    if [ -d "$ANDROID_HOME_DIR" ]; then
        print_kv "SDK ($ANDROID_HOME_DIR):" "$(human_size "$(android_sdk_bytes)") (report only, never auto-removed)"
    else
        print_kv "SDK:" "not found at $ANDROID_HOME_DIR"
    fi
    print_kv "~/.android:" "$(human_size "$(android_dot_dir_bytes)")"
    print_kv "AVDs ($ANDROID_AVD_DIR):" "$(human_size "$(android_avd_bytes)")"
}

_android_running_avd_names() {
    command_exists adb || return 0
    local serial
    adb devices 2>/dev/null | awk '/^emulator-/{print $1}' | while IFS= read -r serial; do
        adb -s "$serial" emu avd name 2>/dev/null | head -n1 | tr -d '\r'
    done
}

android_list_avds() {
    if [ ! -d "$ANDROID_AVD_DIR" ]; then
        echo "No AVD directory found ($ANDROID_AVD_DIR)."
        return 1
    fi

    _AVD_NAMES=()
    local i=0 avd name bytes
    for avd in "$ANDROID_AVD_DIR"/*.avd; do
        [ -d "$avd" ] || continue
        i=$((i + 1))
        name="$(basename "$avd" .avd)"
        bytes="$(path_size_bytes "$avd")"
        _AVD_NAMES+=("$name")
        printf ' %2d) %-30s %s\n' "$i" "$name" "$(human_size "$bytes")"
    done

    [ "$i" -eq 0 ] && { echo "No AVDs found."; return 1; }
    return 0
}

android_delete_avd() {
    echo "Installed Android Virtual Devices:"
    android_list_avds || return 0
    echo

    local running
    running="$(_android_running_avd_names)"

    printf 'Enter numbers to DELETE (space separated), or blank to cancel: '
    local sel
    read -r sel < /dev/tty 2>/dev/null || read -r sel
    [ -z "$sel" ] && { echo "Cancelled."; return 0; }

    local idx name avd_dir ini_file bytes
    for idx in $sel; do
        case "$idx" in
            ''|*[!0-9]*) echo "Skipping invalid selection: $idx"; continue ;;
        esac
        name="${_AVD_NAMES[$((idx - 1))]:-}"
        [ -z "$name" ] && { echo "Skipping invalid selection: $idx"; continue; }

        if [ -n "$running" ] && printf '%s\n' "$running" | grep -qxF "$name"; then
            echo "Refusing to delete \"$name\" - it is currently running in the emulator."
            continue
        fi

        avd_dir="$ANDROID_AVD_DIR/$name.avd"
        ini_file="$ANDROID_AVD_DIR/$name.ini"
        bytes="$(path_size_bytes "$avd_dir")"

        echo
        echo "Target:  $avd_dir"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    This emulator image and all its app data/snapshots."
        echo "Effect:  The AVD disappears from Android Studio's device manager."
        echo "Action:  Remove the AVD directory and its .ini descriptor."
        echo

        if confirm_delete_word "This permanently deletes the AVD."; then
            if command_exists avdmanager; then
                run_or_dry "delete avd $name" avdmanager delete avd -n "$name"
            else
                safe_remove_path "$avd_dir"
                [ -f "$ini_file" ] && safe_remove_path "$ini_file"
            fi
            log_action "deleted" "$avd_dir" "$bytes"
        else
            echo "Skipped $name."
            log_action "skipped" "$avd_dir" "$bytes"
        fi
    done
}

android_clean_project() {
    printf 'Enter the full path to an Android/Gradle project: '
    local project
    read -r project < /dev/tty 2>/dev/null || read -r project
    [ -z "$project" ] && { echo "Cancelled."; return 0; }

    case "$project" in
        "~") project="$HOME" ;;
        "~/"*) project="$HOME/${project#\~/}" ;;
    esac

    if [ ! -d "$project" ]; then
        echo "Not a directory: $project"
        return 0
    fi
    if is_dangerous_path "$project"; then
        echo "Refusing to operate on this path: $project"
        return 0
    fi

    local found=0 name path bytes
    for name in build .gradle; do
        path="$project/$name"
        [ -d "$path" ] || continue
        found=1
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $path"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    Generated build artifacts/local Gradle state for this project only."
        echo "Effect:  Recreated by the next Gradle build."
        echo "Action:  Remove this directory."
        echo

        if confirm_delete_word "Delete $name for this project?"; then
            safe_remove_path "$path"
            log_action "deleted" "$path" "$bytes"
            echo "Removed $name."
        else
            echo "Skipped $name."
            log_action "skipped" "$path" "$bytes"
        fi
    done

    [ "$found" -eq 0 ] && echo "No build or .gradle folder found directly inside $project."
}

android_menu() {
    local choice
    while true; do
        section_header "Android cleanup"
        print_kv "AVDs:" "$(human_size "$(android_avd_bytes)")"
        print_kv "~/.android:" "$(human_size "$(android_dot_dir_bytes)")"
        echo
        cat <<'EOF'
  1) List / delete AVDs
  2) Clean build/.gradle for a specific project
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) android_delete_avd ;;
            2) android_clean_project ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}

# Combined menu for the top-level "Android / Gradle cleanup" entry.
android_gradle_menu() {
    local choice
    while true; do
        section_header "Android / Gradle cleanup"
        cat <<'EOF'
  1) Android AVDs and per-project build cleanup
  2) Gradle caches / wrapper cleanup
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) android_menu ;;
            2) gradle_menu ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
    done
}
