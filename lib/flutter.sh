#!/bin/bash
# Flutter / Dart cleanup.
#
# Safety model:
#  - ~/.pub-cache is a shared, recreatable download cache: y/N is enough.
#  - .dart_tool / build folders are only ever touched inside a project path
#    the user explicitly types in - never a recursive sweep of $HOME - and
#    removing them requires typing DELETE (they can hold uncommitted
#    generated code the user may not expect to lose).

flutter_pub_cache_bytes() {
    path_size_bytes "$PUB_CACHE_DIR"
}

flutter_sdk_root() {
    command_exists flutter || return 1
    local bin_path resolved
    bin_path="$(command -v flutter)"

    # Resolve symlinks (e.g. a Homebrew or asdf shim) to the real script.
    while [ -h "$bin_path" ]; do
        resolved="$(readlink "$bin_path")"
        case "$resolved" in
            /*) bin_path="$resolved" ;;
            *) bin_path="$(dirname "$bin_path")/$resolved" ;;
        esac
    done

    # flutter lives at <sdk-root>/bin/flutter
    ( cd -P "$(dirname "$bin_path")/.." >/dev/null 2>&1 && pwd )
}

flutter_sdk_cache_bytes() {
    local root
    root="$(flutter_sdk_root 2>/dev/null)"
    [ -z "$root" ] && { echo 0; return 0; }
    path_size_bytes "$root/bin/cache"
}

flutter_scan() {
    section_header "Flutter / Dart"
    if command_exists flutter; then
        print_kv "Flutter SDK:" "$(flutter_sdk_root 2>/dev/null)"
        print_kv "Flutter SDK cache:" "$(human_size "$(flutter_sdk_cache_bytes)")"
    else
        print_kv "Flutter SDK:" "not found on PATH"
    fi
    print_kv "pub-cache ($PUB_CACHE_DIR):" "$(human_size "$(flutter_pub_cache_bytes)")"
}

# _flutter_do_clean_pub_cache <bytes>
# The actual removal, shared by the interactive menu and quick clean.
_flutter_do_clean_pub_cache() {
    safe_remove_path "$PUB_CACHE_DIR"
    log_action "deleted" "$PUB_CACHE_DIR" "${1:-0}"
}

flutter_clean_pub_cache() {
    local bytes
    bytes="$(flutter_pub_cache_bytes)"

    if [ "$bytes" -eq 0 ]; then
        echo "pub-cache is empty or does not exist. Nothing to clean."
        return 0
    fi

    echo "Target:  $PUB_CACHE_DIR"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Downloaded pub package versions."
    echo "Effect:  Recreated automatically on the next 'flutter pub get' /"
    echo "         'dart pub get' (requires network access)."
    echo "Action:  Remove the entire pub-cache directory."
    echo

    if confirm_yes_no "Delete pub-cache now?"; then
        _flutter_do_clean_pub_cache "$bytes"
        echo "pub-cache removed."
    else
        echo "Skipped."
        log_action "skipped" "$PUB_CACHE_DIR" "$bytes"
    fi
}

flutter_clean_project() {
    printf 'Enter the full path to a Flutter/Dart project: '
    local project
    read -r project < /dev/tty 2>/dev/null || read -r project
    [ -z "$project" ] && { echo "Cancelled."; return 0; }

    # Expand a leading ~ manually (no eval).
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
    for name in .dart_tool build; do
        path="$project/$name"
        [ -d "$path" ] || continue
        found=1
        bytes="$(path_size_bytes "$path")"

        echo
        echo "Target:  $path"
        echo "Size:    $(human_size "$bytes")"
        echo "Lost:    Generated build artifacts for this project only."
        echo "Effect:  Recreated by the next 'flutter build' / 'flutter run'."
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

    [ "$found" -eq 0 ] && echo "No .dart_tool or build folder found directly inside $project."
}

flutter_menu() {
    local choice
    while true; do
        section_header "Flutter cleanup"
        print_kv "pub-cache:" "$(human_size "$(flutter_pub_cache_bytes)")"
        if command_exists flutter; then
            print_kv "SDK cache:" "$(human_size "$(flutter_sdk_cache_bytes)")"
        fi
        echo
        cat <<'EOF'
  1) Clean pub-cache (safe)
  2) Clean .dart_tool/build for a specific project
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) flutter_clean_pub_cache ;;
            2) flutter_clean_project ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
