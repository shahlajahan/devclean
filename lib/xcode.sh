#!/bin/bash
# Xcode cleanup: DerivedData, iOS DeviceSupport, Archives.
#
# Safety model:
#  - DerivedData: safe to delete after confirmation (y/N). Next build is
#    just slower, nothing is lost.
#  - iOS DeviceSupport: listed only, never auto-deleted. Removing a version
#    means Xcode may need to regenerate on-device debugging support.
#  - Archives: listed only, require explicit selection + typing DELETE.

xcode_derived_data_bytes() {
    path_size_bytes "$XCODE_DERIVED_DATA_DIR"
}

xcode_devicesupport_bytes() {
    path_size_bytes "$XCODE_DEVICE_SUPPORT_DIR"
}

xcode_archives_bytes() {
    path_size_bytes "$XCODE_ARCHIVES_DIR"
}

xcode_scan() {
    section_header "Xcode"
    print_kv "DerivedData ($XCODE_DERIVED_DATA_DIR):" "$(human_size "$(xcode_derived_data_bytes)")"
    print_kv "iOS DeviceSupport:" "$(human_size "$(xcode_devicesupport_bytes)")"
    print_kv "Archives:" "$(human_size "$(xcode_archives_bytes)")"
}

# _xcode_do_clean_derived_data <bytes>
# The actual removal, shared by the interactive menu (after its own y/N)
# and quick clean (after its single consolidated confirmation).
_xcode_do_clean_derived_data() {
    safe_remove_path "$XCODE_DERIVED_DATA_DIR"
    log_action "deleted" "$XCODE_DERIVED_DATA_DIR" "${1:-0}"
}

xcode_clean_derived_data() {
    local bytes
    bytes="$(xcode_derived_data_bytes)"

    if [ "$bytes" -eq 0 ]; then
        echo "DerivedData is empty or does not exist. Nothing to clean."
        return 0
    fi

    echo "Target:  $XCODE_DERIVED_DATA_DIR"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Cached build products and indexes for every Xcode project."
    echo "Effect:  The next build of each project will be slower (full rebuild)."
    echo "Action:  Remove the entire DerivedData directory."
    echo

    if confirm_yes_no "Delete DerivedData now?"; then
        _xcode_do_clean_derived_data "$bytes"
        echo "DerivedData removed."
    else
        echo "Skipped."
        log_action "skipped" "$XCODE_DERIVED_DATA_DIR" "$bytes"
    fi
}

# --- iOS DeviceSupport ------------------------------------------------------

xcode_list_devicesupport() {
    if [ ! -d "$XCODE_DEVICE_SUPPORT_DIR" ]; then
        echo "No iOS DeviceSupport directory found."
        return 1
    fi

    local i=0
    _DEVSUPPORT_NAMES=()
    for d in "$XCODE_DEVICE_SUPPORT_DIR"/*/; do
        [ -d "$d" ] || continue
        i=$((i + 1))
        local name bytes
        name="$(basename "$d")"
        bytes="$(path_size_bytes "$d")"
        _DEVSUPPORT_NAMES+=("$name")
        printf ' %2d) %-45s %s\n' "$i" "$name" "$(human_size "$bytes")"
    done

    [ "$i" -eq 0 ] && { echo "No installed DeviceSupport versions found."; return 1; }
    return 0
}

xcode_clean_devicesupport() {
    echo "Installed iOS DeviceSupport versions:"
    xcode_list_devicesupport || return 0
    echo
    echo "Removing a version means Xcode may need to re-download/regenerate"
    echo "support files the next time you debug on a physical device running"
    echo "that iOS version."
    echo
    printf 'Enter numbers to remove (space separated), or blank to cancel: '
    local sel
    read -r sel < /dev/tty 2>/dev/null || read -r sel
    [ -z "$sel" ] && { echo "Cancelled."; return 0; }

    local idx name path bytes
    for idx in $sel; do
        case "$idx" in
            ''|*[!0-9]*) echo "Skipping invalid selection: $idx"; continue ;;
        esac
        name="${_DEVSUPPORT_NAMES[$((idx - 1))]:-}"
        [ -z "$name" ] && { echo "Skipping invalid selection: $idx"; continue; }
        path="$XCODE_DEVICE_SUPPORT_DIR/$name"
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $path"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    On-device debugging support files for iOS \"$name\"."
        echo "Effect:  Xcode may need to regenerate support for this iOS version"
        echo "         the next time a matching device is connected."
        echo "Action:  Remove this DeviceSupport directory."
        echo

        if confirm_delete_word "This is a high-impact removal."; then
            safe_remove_path "$path"
            log_action "deleted" "$path" "$bytes"
            echo "Removed $name."
        else
            echo "Skipped $name."
            log_action "skipped" "$path" "$bytes"
        fi
    done
}

# --- Archives ----------------------------------------------------------

xcode_list_archives() {
    if [ ! -d "$XCODE_ARCHIVES_DIR" ]; then
        echo "No Archives directory found."
        return 1
    fi

    local i=0
    _ARCHIVE_PATHS=()
    while IFS= read -r -d '' archive; do
        i=$((i + 1))
        local bytes mtime
        bytes="$(path_size_bytes "$archive")"
        mtime="$(stat -f '%Sm' -t '%Y-%m-%d' "$archive" 2>/dev/null)"
        _ARCHIVE_PATHS+=("$archive")
        printf ' %2d) %-45s %-12s %s\n' "$i" "$(basename "$archive")" "$mtime" "$(human_size "$bytes")"
    done < <(find "$XCODE_ARCHIVES_DIR" -maxdepth 2 -type d -name '*.xcarchive' -print0 2>/dev/null)

    [ "$i" -eq 0 ] && { echo "No archives found."; return 1; }
    return 0
}

xcode_clean_archives() {
    echo "Xcode Archives:"
    xcode_list_archives || return 0
    echo
    echo "Archives contain signed, distributable builds. Recent archives are"
    echo "not removed automatically - you must explicitly select which to delete."
    echo
    printf 'Enter numbers to remove (space separated), or blank to cancel: '
    local sel
    read -r sel < /dev/tty 2>/dev/null || read -r sel
    [ -z "$sel" ] && { echo "Cancelled."; return 0; }

    local idx path bytes
    for idx in $sel; do
        case "$idx" in
            ''|*[!0-9]*) echo "Skipping invalid selection: $idx"; continue ;;
        esac
        path="${_ARCHIVE_PATHS[$((idx - 1))]:-}"
        [ -z "$path" ] && { echo "Skipping invalid selection: $idx"; continue; }
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $path"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    This archived build and its dSYMs. Cannot re-upload or"
        echo "         re-symbolicate crashes for this build once removed."
        echo "Effect:  Not recoverable unless you re-archive from source."
        echo "Action:  Remove this .xcarchive."
        echo

        if confirm_delete_word "This is a high-impact removal."; then
            safe_remove_path "$path"
            log_action "deleted" "$path" "$bytes"
            echo "Removed $(basename "$path")."
        else
            echo "Skipped $(basename "$path")."
            log_action "skipped" "$path" "$bytes"
        fi
    done
}

xcode_menu() {
    local choice
    while true; do
        section_header "Xcode cleanup"
        print_kv "DerivedData:" "$(human_size "$(xcode_derived_data_bytes)")"
        print_kv "iOS DeviceSupport:" "$(human_size "$(xcode_devicesupport_bytes)")"
        print_kv "Archives:" "$(human_size "$(xcode_archives_bytes)")"
        echo
        cat <<'EOF'
  1) Clean DerivedData (safe)
  2) Review/remove old iOS DeviceSupport versions
  3) Review/remove Xcode Archives
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) xcode_clean_derived_data ;;
            2) xcode_clean_devicesupport ;;
            3) xcode_clean_archives ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
