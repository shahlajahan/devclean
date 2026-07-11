#!/bin/bash
# Quick clean orchestration and the top-level "devclean clean" menu.
#
# Quick clean is deliberately restricted to low-risk, fully recreatable
# caches. It never touches simulators, iOS DeviceSupport, Xcode Archives,
# Docker, WhatsApp, project source, credentials, databases, SSH files,
# signing material, provisioning profiles, Firebase config, or .env files.

quick_clean_run() {
    section_header "Quick clean"
    echo "Quick clean only ever touches safe, recreatable caches:"
    echo "  - Xcode DerivedData"
    echo "  - CocoaPods cache"
    echo "  - Flutter/Dart pub-cache"
    echo "  - npm and yarn cache"
    echo "  - Homebrew cache"
    echo "  - devclean's own logs older than $LOG_RETENTION_DAYS days"
    echo
    echo "It never touches simulators, iOS DeviceSupport, Xcode Archives,"
    echo "Docker, WhatsApp, project source, credentials, databases, SSH"
    echo "files, signing certificates, provisioning profiles, Firebase"
    echo "config, or .env files."
    echo

    local dd_bytes pod_bytes pub_bytes npm_bytes yarn_bytes brew_bytes logs_bytes
    dd_bytes="$(xcode_derived_data_bytes)"
    pod_bytes="$(cocoapods_cache_bytes)"
    pub_bytes="$(flutter_pub_cache_bytes)"
    npm_bytes=0
    command_exists npm && npm_bytes="$(node_npm_cache_bytes)"
    yarn_bytes=0
    command_exists yarn && yarn_bytes="$(node_yarn_cache_bytes)"
    brew_bytes=0
    brew_available && brew_bytes="$(brew_cache_bytes)"

    local old_logs
    old_logs="$(logger_prune_old "$LOG_RETENTION_DAYS")"
    logs_bytes=0
    if [ -n "$old_logs" ]; then
        local f
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            logs_bytes=$(( logs_bytes + $(path_size_bytes "$f") ))
        done <<< "$old_logs"
    fi

    echo "Planned actions:"
    print_kv "Xcode DerivedData:" "$(human_size "$dd_bytes")"
    print_kv "CocoaPods cache:" "$(human_size "$pod_bytes")"
    print_kv "Flutter pub-cache:" "$(human_size "$pub_bytes")"
    print_kv "npm cache:" "$(human_size "$npm_bytes")"
    print_kv "yarn cache:" "$(human_size "$yarn_bytes")"
    print_kv "Homebrew cache:" "$(human_size "$brew_bytes")"
    print_kv "Old devclean logs (>${LOG_RETENTION_DAYS}d):" "$(human_size "$logs_bytes")"

    local total
    total="$(sum_bytes "$dd_bytes" "$pod_bytes" "$pub_bytes" "$npm_bytes" "$yarn_bytes" "$brew_bytes" "$logs_bytes")"
    echo
    print_kv "Total estimated:" "$(human_size "$total")"
    echo

    if [ "$total" -eq 0 ]; then
        echo "Nothing to clean."
        return 0
    fi

    if ! confirm_yes_no "Proceed with quick clean of the above items?"; then
        echo "Quick clean skipped."
        log_action "skipped" "quick-clean" "$total"
        return 0
    fi

    # Each of these delegates to the same private helper the interactive
    # per-category menu uses, so the actual cleanup command is defined in
    # exactly one place.
    [ "$dd_bytes" -gt 0 ] && _xcode_do_clean_derived_data "$dd_bytes"
    [ "$pod_bytes" -gt 0 ] && _cocoapods_do_clean_cache "$pod_bytes"
    [ "$pub_bytes" -gt 0 ] && _flutter_do_clean_pub_cache "$pub_bytes"
    [ "$npm_bytes" -gt 0 ] && command_exists npm && _node_do_clean_npm "$npm_bytes"
    [ "$yarn_bytes" -gt 0 ] && command_exists yarn && _node_do_clean_yarn "$yarn_bytes"
    [ "$brew_bytes" -gt 0 ] && brew_available && _brew_do_clean "$brew_bytes"

    if [ -n "$old_logs" ]; then
        local f
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            safe_remove_path "$f"
        done <<< "$old_logs"
        log_action "deleted" "old-devclean-logs" "$logs_bytes"
    fi

    echo
    echo "Quick clean complete. Estimated space recovered: $(human_size "$total")"
}

clean_menu() {
    local choice
    while true; do
        section_header "devclean - safe clean menu"
        cat <<'EOF'
  1) Quick clean (safe caches only)
  2) Xcode cleanup
  3) Simulator cleanup
  4) Android / Gradle cleanup
  5) Flutter cleanup
  6) Node cleanup
  7) Docker cleanup
  8) CocoaPods cleanup
  9) Homebrew cleanup
 10) WhatsApp storage audit
 11) Bun cleanup
 12) Multi-select cleanup
  0) Exit
EOF
        echo
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        echo
        case "$choice" in
            1) quick_clean_run ;;
            2) xcode_menu ;;
            3) simulator_menu ;;
            4) android_gradle_menu ;;
            5) flutter_menu ;;
            6) node_menu ;;
            7) docker_menu ;;
            8) cocoapods_menu ;;
            9) brew_menu ;;
            10) whatsapp_menu ;;
            11) bun_menu ;;
            12) multi_select_clean_menu ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}

# multi_select_clean_menu
# Lets the user pick several cleanup categories at once, then runs each
# selected category's existing interactive menu in sequence. This is pure
# orchestration - it introduces no new cleanup logic, so every category
# keeps its own existing per-item confirmation (y/N or DELETE) untouched.
multi_select_clean_menu() {
    local labels=(
        "Xcode cleanup"
        "Simulator cleanup"
        "Android / Gradle cleanup"
        "Flutter cleanup"
        "Node cleanup"
        "Bun cleanup"
        "Docker cleanup"
        "CocoaPods cleanup"
        "Homebrew cleanup"
    )
    local funcs=(
        xcode_menu
        simulator_menu
        android_gradle_menu
        flutter_menu
        node_menu
        bun_menu
        docker_menu
        cocoapods_menu
        brew_menu
    )

    local selection
    if ! selection="$(multi_select_prompt "Multi-select cleanup - choose one or more categories" "${labels[@]}")"; then
        echo "Cancelled."
        return 0
    fi
    if [ -z "$selection" ]; then
        echo "Nothing selected."
        return 0
    fi

    echo
    echo "Will open, in order:"
    local idx
    for idx in $selection; do
        echo "  - ${labels[$((idx - 1))]}"
    done
    echo

    if ! confirm_yes_no "Proceed through the selected categories in order?"; then
        echo "Cancelled."
        return 0
    fi

    for idx in $selection; do
        "${funcs[$((idx - 1))]}"
    done
}
