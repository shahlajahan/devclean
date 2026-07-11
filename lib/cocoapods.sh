#!/bin/bash
# CocoaPods cleanup.
#
# Safety model:
#  - ~/Library/Caches/CocoaPods and ~/.cocoapods are redownloadable caches:
#    y/N is sufficient.
#  - A project's Pods/ directory is only ever touched when the user
#    explicitly supplies that project's path, and removing it requires
#    typing DELETE since it can contain locally-modified pods.

cocoapods_cache_bytes() {
    path_size_bytes "$COCOAPODS_CACHE_DIR"
}

cocoapods_dot_dir_bytes() {
    path_size_bytes "$COCOAPODS_DOT_DIR"
}

cocoapods_scan() {
    section_header "CocoaPods"
    print_kv "Cache ($COCOAPODS_CACHE_DIR):" "$(human_size "$(cocoapods_cache_bytes)")"
    print_kv "~/.cocoapods:" "$(human_size "$(cocoapods_dot_dir_bytes)")"
}

# _cocoapods_do_clean_cache <bytes>
# The actual removal, shared by the interactive menu and quick clean.
_cocoapods_do_clean_cache() {
    if command_exists pod; then
        run_or_dry "pod cache clean --all" pod cache clean --all
    else
        safe_remove_path "$COCOAPODS_CACHE_DIR"
    fi
    log_action "deleted" "$COCOAPODS_CACHE_DIR" "${1:-0}"
}

cocoapods_clean_cache() {
    local bytes
    bytes="$(cocoapods_cache_bytes)"
    if [ "$bytes" -eq 0 ]; then
        echo "CocoaPods cache is empty or does not exist."
        return 0
    fi

    echo "Target:  $COCOAPODS_CACHE_DIR"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Downloaded pod spec/source cache."
    echo "Effect:  Redownloaded automatically on the next 'pod install'."
    echo "Action:  Remove the CocoaPods cache directory."
    echo

    if confirm_yes_no "Delete CocoaPods cache now?"; then
        _cocoapods_do_clean_cache "$bytes"
        echo "CocoaPods cache removed."
    else
        echo "Skipped."
        log_action "skipped" "$COCOAPODS_CACHE_DIR" "$bytes"
    fi
}

cocoapods_clean_project_pods() {
    printf 'Enter the full path to a project containing an ios/Pods folder: '
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

    local candidates=("$project/Pods" "$project/ios/Pods")
    local path bytes found=0
    for path in "${candidates[@]}"; do
        [ -d "$path" ] || continue
        found=1
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $path"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    Installed pod sources for this project, including any"
        echo "         locally-modified pods that are not tracked elsewhere."
        echo "Effect:  Recreated by running 'pod install' again."
        echo "Action:  Remove this Pods directory."
        echo

        if confirm_delete_word "Delete Pods for this project?"; then
            safe_remove_path "$path"
            log_action "deleted" "$path" "$bytes"
            echo "Removed $path."
        else
            echo "Skipped $path."
            log_action "skipped" "$path" "$bytes"
        fi
    done

    [ "$found" -eq 0 ] && echo "No Pods directory found at $project/Pods or $project/ios/Pods."
}

cocoapods_menu() {
    local choice
    while true; do
        section_header "CocoaPods cleanup"
        print_kv "Cache:" "$(human_size "$(cocoapods_cache_bytes)")"
        echo
        cat <<'EOF'
  1) Clean CocoaPods cache (safe)
  2) Clean Pods/ for a specific project
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) cocoapods_clean_cache ;;
            2) cocoapods_clean_project_pods ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
