#!/bin/bash
# Homebrew cache cleanup. Entirely optional - only activates if `brew` is
# on PATH. `brew cleanup -n` is Homebrew's own dry-run and is used to
# preview exactly what would be removed before asking for confirmation.

brew_available() {
    command_exists brew
}

brew_cache_dir() {
    brew_available || { echo ""; return 0; }
    brew --cache 2>/dev/null
}

brew_cache_bytes() {
    local dir
    dir="$(brew_cache_dir)"
    [ -z "$dir" ] && { echo 0; return 0; }
    path_size_bytes "$dir"
}

brew_scan() {
    section_header "Homebrew"
    if ! brew_available; then
        print_kv "Status:" "not installed"
        return 0
    fi
    print_kv "Cache ($(brew_cache_dir)):" "$(human_size "$(brew_cache_bytes)")"
}

# _brew_do_clean <bytes>
# The actual cleanup, shared by the interactive menu and quick clean.
_brew_do_clean() {
    run_or_dry "brew cleanup" brew cleanup
    log_action "cleaned" "$(brew_cache_dir)" "${1:-0}"
}

brew_clean() {
    if ! brew_available; then
        echo "Homebrew is not installed."
        return 0
    fi

    local bytes
    bytes="$(brew_cache_bytes)"

    echo "Preview (brew cleanup -n):"
    brew cleanup -n 2>/dev/null | sed 's/^/  /'
    echo
    echo "Target:  $(brew_cache_dir)"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Old formula/cask download and build artifacts."
    echo "Effect:  Redownloaded automatically if needed again."
    echo "Action:  brew cleanup"
    echo

    if confirm_yes_no "Run 'brew cleanup' now?"; then
        _brew_do_clean "$bytes"
    else
        echo "Skipped."
        log_action "skipped" "$(brew_cache_dir)" "$bytes"
    fi
}

brew_menu() {
    local choice
    while true; do
        section_header "Homebrew cleanup"
        brew_scan
        echo
        cat <<'EOF'
  1) Preview and run brew cleanup
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) brew_clean ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
