#!/bin/bash
# Node.js package manager cache cleanup (npm, yarn, pnpm).
#
# Safety model: package manager caches are redownloadable, so y/N is
# sufficient. Cleanup always goes through each tool's own native cache
# command rather than rm -rf, since that is the officially supported way
# to clear them. node_modules directories are never touched by this tool.

node_npm_cache_dir() {
    if command_exists npm; then
        npm config get cache 2>/dev/null
    else
        echo "$HOME/.npm"
    fi
}

node_yarn_cache_dir() {
    if command_exists yarn; then
        yarn cache dir 2>/dev/null
    else
        echo "$HOME/Library/Caches/Yarn"
    fi
}

node_pnpm_store_dir() {
    if command_exists pnpm; then
        pnpm store path 2>/dev/null
    else
        echo "$HOME/Library/pnpm/store"
    fi
}

node_npm_cache_bytes() {
    local dir
    dir="$(node_npm_cache_dir)"
    path_size_bytes "$dir"
}

node_yarn_cache_bytes() {
    local dir
    dir="$(node_yarn_cache_dir)"
    path_size_bytes "$dir"
}

node_pnpm_store_bytes() {
    local dir
    dir="$(node_pnpm_store_dir)"
    path_size_bytes "$dir"
}

node_cache_bytes() {
    sum_bytes "$(node_npm_cache_bytes)" "$(node_yarn_cache_bytes)" "$(node_pnpm_store_bytes)"
}

node_scan() {
    section_header "Node.js"
    if command_exists npm; then
        print_kv "npm cache ($(node_npm_cache_dir)):" "$(human_size "$(node_npm_cache_bytes)")"
    else
        print_kv "npm:" "not installed"
    fi
    if command_exists yarn; then
        print_kv "yarn cache ($(node_yarn_cache_dir)):" "$(human_size "$(node_yarn_cache_bytes)")"
    else
        print_kv "yarn:" "not installed"
    fi
    if command_exists pnpm; then
        print_kv "pnpm store ($(node_pnpm_store_dir)):" "$(human_size "$(node_pnpm_store_bytes)")"
    else
        print_kv "pnpm:" "not installed"
    fi
}

# _node_do_clean_npm <bytes>
# The actual cache clean, shared by the interactive menu and quick clean.
_node_do_clean_npm() {
    run_or_dry "npm cache clean --force" npm cache clean --force
    log_action "deleted" "$(node_npm_cache_dir)" "${1:-0}"
}

node_clean_npm() {
    if ! command_exists npm; then
        echo "npm is not installed."
        return 0
    fi
    local dir bytes
    dir="$(node_npm_cache_dir)"
    bytes="$(path_size_bytes "$dir")"

    echo "Target:  $dir"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Cached downloaded npm packages."
    echo "Effect:  Redownloaded automatically on the next 'npm install'."
    echo "Action:  npm cache clean --force"
    echo

    if confirm_yes_no "Clean npm cache now?"; then
        _node_do_clean_npm "$bytes"
    else
        echo "Skipped."
        log_action "skipped" "$dir" "$bytes"
    fi
}

# _node_do_clean_yarn <bytes>
# The actual cache clean, shared by the interactive menu and quick clean.
_node_do_clean_yarn() {
    run_or_dry "yarn cache clean" yarn cache clean
    log_action "deleted" "$(node_yarn_cache_dir)" "${1:-0}"
}

node_clean_yarn() {
    if ! command_exists yarn; then
        echo "yarn is not installed."
        return 0
    fi
    local dir bytes
    dir="$(node_yarn_cache_dir)"
    bytes="$(path_size_bytes "$dir")"

    echo "Target:  $dir"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Cached downloaded yarn packages."
    echo "Effect:  Redownloaded automatically on the next 'yarn install'."
    echo "Action:  yarn cache clean"
    echo

    if confirm_yes_no "Clean yarn cache now?"; then
        _node_do_clean_yarn "$bytes"
    else
        echo "Skipped."
        log_action "skipped" "$dir" "$bytes"
    fi
}

node_clean_pnpm() {
    if ! command_exists pnpm; then
        echo "pnpm is not installed."
        return 0
    fi
    local dir bytes
    dir="$(node_pnpm_store_dir)"
    bytes="$(path_size_bytes "$dir")"

    echo "Target:  $dir"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Unreferenced packages in the pnpm content-addressable store."
    echo "Effect:  Redownloaded only if no other project references them."
    echo "Action:  pnpm store prune"
    echo

    if confirm_yes_no "Prune pnpm store now?"; then
        run_or_dry "pnpm store prune" pnpm store prune
        log_action "deleted" "$dir" "$bytes"
    else
        echo "Skipped."
        log_action "skipped" "$dir" "$bytes"
    fi
}

node_menu() {
    local choice
    while true; do
        section_header "Node cleanup"
        node_scan
        echo
        cat <<'EOF'
  1) Clean npm cache (safe)
  2) Clean yarn cache (safe)
  3) Prune pnpm store (safe)
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) node_clean_npm ;;
            2) node_clean_yarn ;;
            3) node_clean_pnpm ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
