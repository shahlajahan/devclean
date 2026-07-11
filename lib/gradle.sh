#!/bin/bash
# Gradle cache cleanup (used by Android and some Flutter plugin builds).
#
# Safety model: ~/.gradle/caches and ~/.gradle/wrapper are redownloaded
# automatically on the next build, so y/N is sufficient.

gradle_caches_bytes() {
    path_size_bytes "$GRADLE_CACHES_DIR"
}

gradle_wrapper_bytes() {
    path_size_bytes "$GRADLE_WRAPPER_DIR"
}

gradle_scan() {
    section_header "Gradle"
    print_kv "Caches ($GRADLE_CACHES_DIR):" "$(human_size "$(gradle_caches_bytes)")"
    print_kv "Wrapper distributions ($GRADLE_WRAPPER_DIR):" "$(human_size "$(gradle_wrapper_bytes)")"
}

gradle_clean_caches() {
    local bytes
    bytes="$(gradle_caches_bytes)"
    if [ "$bytes" -eq 0 ]; then
        echo "Gradle caches directory is empty or does not exist."
        return 0
    fi

    echo "Target:  $GRADLE_CACHES_DIR"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Downloaded Gradle module/dependency caches."
    echo "Effect:  Redownloaded automatically on the next Gradle build."
    echo "Action:  Remove the Gradle caches directory."
    echo

    if confirm_yes_no "Delete Gradle caches now?"; then
        safe_remove_path "$GRADLE_CACHES_DIR"
        log_action "deleted" "$GRADLE_CACHES_DIR" "$bytes"
        echo "Gradle caches removed."
    else
        echo "Skipped."
        log_action "skipped" "$GRADLE_CACHES_DIR" "$bytes"
    fi
}

gradle_clean_wrapper() {
    local bytes
    bytes="$(gradle_wrapper_bytes)"
    if [ "$bytes" -eq 0 ]; then
        echo "Gradle wrapper directory is empty or does not exist."
        return 0
    fi

    echo "Target:  $GRADLE_WRAPPER_DIR"
    echo "Size:    $(human_size "$bytes")"
    echo "Lost:    Downloaded Gradle wrapper distributions."
    echo "Effect:  Redownloaded automatically the next time a project's"
    echo "         ./gradlew is invoked."
    echo "Action:  Remove the Gradle wrapper directory."
    echo

    if confirm_yes_no "Delete Gradle wrapper distributions now?"; then
        safe_remove_path "$GRADLE_WRAPPER_DIR"
        log_action "deleted" "$GRADLE_WRAPPER_DIR" "$bytes"
        echo "Gradle wrapper distributions removed."
    else
        echo "Skipped."
        log_action "skipped" "$GRADLE_WRAPPER_DIR" "$bytes"
    fi
}

gradle_menu() {
    local choice
    while true; do
        section_header "Gradle cleanup"
        print_kv "Caches:" "$(human_size "$(gradle_caches_bytes)")"
        print_kv "Wrapper distributions:" "$(human_size "$(gradle_wrapper_bytes)")"
        echo
        cat <<'EOF'
  1) Clean Gradle caches (safe)
  2) Clean Gradle wrapper distributions (safe)
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) gradle_clean_caches ;;
            2) gradle_clean_wrapper ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
