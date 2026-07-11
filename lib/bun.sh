#!/bin/bash
# Bun cleanup.
#
# Safety model: Bun's package cache is redownloadable, so y/N is
# sufficient. Cleanup goes through Bun's own cache command rather than
# rm -rf, matching how npm/yarn/pnpm are handled in lib/node.sh.

bun_available() {
    command_exists bun
}

bun_version() {
    bun_available && bun --version 2>/dev/null
}

bun_cache_dir() {
    if bun_available; then
        bun pm cache dir 2>/dev/null
    else
        echo "$HOME/.bun/install/cache"
    fi
}

bun_cache_bytes() {
    path_size_bytes "$(bun_cache_dir)"
}

bun_scan() {
    section_header "Bun"
    if bun_available; then
        print_kv "Version:" "$(bun_version)"
        print_kv "Cache ($(bun_cache_dir)):" "$(human_size "$(bun_cache_bytes)")"
    else
        print_kv "Status:" "not installed"
    fi
}

# _bun_do_clean_cache <bytes>
# The actual cache clean, shared by the interactive menu and any future caller.
_bun_do_clean_cache() {
    run_or_dry "bun pm cache rm" bun pm cache rm
    log_action "deleted" "$(bun_cache_dir)" "${1:-0}"
}

bun_clean_cache() {
    if ! bun_available; then
        echo "Bun is not installed."
        return 0
    fi
    local bytes
    bytes="$(bun_cache_bytes)"
    if [ "$bytes" -eq 0 ]; then
        echo "Bun cache is empty or does not exist."
        return 0
    fi

    echo "Target:  $(bun_cache_dir)"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Cached downloaded Bun packages."
    echo "Effect:  Redownloaded automatically on the next 'bun install'."
    echo "Action:  bun pm cache rm"
    echo

    if confirm_yes_no "Clean Bun cache now?"; then
        _bun_do_clean_cache "$bytes"
    else
        echo "Skipped."
        log_action "skipped" "$(bun_cache_dir)" "$bytes"
    fi
}

bun_menu() {
    local choice
    while true; do
        section_header "Bun cleanup"
        bun_scan
        echo
        cat <<'EOF'
  1) Clean Bun cache (safe)
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) bun_clean_cache ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
