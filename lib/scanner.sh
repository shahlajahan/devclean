#!/bin/bash
# Top-level "devclean scan" orchestration and the reclaimable-space estimate
# shown in the interactive menu header. Read-only - no deletions happen here.

scan_command() {
    menu_banner_if_needed

    local steps=(
        "Disk" "General locations" "Xcode" "Simulator" "Flutter" "Gradle"
        "Android" "CocoaPods" "Node" "Bun" "Docker" "Homebrew" "WhatsApp"
    )
    local total=${#steps[@]}
    local step=0

    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    disk_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    general_locations_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    xcode_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    simulator_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    flutter_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    gradle_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    android_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    cocoapods_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    node_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    bun_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    docker_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    brew_scan
    step=$((step + 1)); progress_bar "$step" "$total" "Scanning: ${steps[$((step - 1))]}"
    whatsapp_scan

    # Computed once and reused below for both the list and the single
    # biggest-item highlight - no repeat scanning.
    local top_consumers
    top_consumers="$(_scan_top_consumers)"

    section_header "Top Space Consumers"
    local rank=1 bytes label
    while IFS='|' read -r bytes label; do
        case "$bytes" in ''|*[!0-9]*) continue ;; esac
        [ "$bytes" -le 0 ] && continue
        printf '  %d. %-28s %s\n' "$rank" "$label" "$(human_size "$bytes")"
        rank=$((rank + 1))
    done <<< "$top_consumers"

    section_header "Summary"
    print_kv "Estimated safe cleanup:" "$(human_size "$(estimate_safe_cleanup_bytes)")"
    print_kv "Estimated risky cleanup:" "$(human_size "$(estimate_risky_cleanup_bytes)")"
    print_kv "Estimated reclaimable:" "$(human_size "$(estimate_reclaimable_bytes)")"

    local biggest_bytes biggest_label
    IFS='|' read -r biggest_bytes biggest_label <<< "$(head -n1 <<< "$top_consumers")"
    case "${biggest_bytes:-}" in
        ''|*[!0-9]*) biggest_bytes=0 ;;
    esac
    if [ "$biggest_bytes" -gt 0 ]; then
        echo
        echo "Biggest cleanup opportunity"
        echo "  $(human_size "$biggest_bytes")"
        echo "  $biggest_label"
    fi

    echo
    echo "Run 'devclean clean' to review and clean these locations safely."
}

menu_banner_if_needed() {
    if [ "${COMMAND:-}" = "scan" ]; then
        logo
        echo
        echo "Scanning developer-related disk usage..."
    fi
}

# _scan_top_consumers
# Every measured cache/tool as "bytes|label", largest first, top 5. Pure
# presentation over the existing *_bytes getters - no new measurement code.
_scan_top_consumers() {
    {
        printf '%s|Xcode DerivedData\n' "$(xcode_derived_data_bytes)"
        printf '%s|iOS DeviceSupport\n' "$(xcode_devicesupport_bytes)"
        printf '%s|Xcode Archives\n' "$(xcode_archives_bytes)"
        printf '%s|Simulator devices\n' "$(simulator_devices_bytes)"
        printf '%s|Flutter pub-cache\n' "$(flutter_pub_cache_bytes)"
        printf '%s|Flutter SDK cache\n' "$(flutter_sdk_cache_bytes)"
        printf '%s|Gradle caches\n' "$(gradle_caches_bytes)"
        printf '%s|Android AVDs\n' "$(android_avd_bytes)"
        printf '%s|CocoaPods cache\n' "$(cocoapods_cache_bytes)"
        printf '%s|npm cache\n' "$(node_npm_cache_bytes)"
        printf '%s|yarn cache\n' "$(node_yarn_cache_bytes)"
        printf '%s|pnpm store\n' "$(node_pnpm_store_bytes)"
        printf '%s|Bun cache\n' "$(bun_cache_bytes)"
        printf '%s|Homebrew cache\n' "$(brew_cache_bytes)"
        printf '%s|Docker reclaimable\n' "$(docker_reclaimable_bytes)"
    } | sort -t'|' -k1,1nr | head -n 5
}

# estimate_safe_cleanup_bytes
# Sum of every cache this tool only ever clears with a y/N confirmation -
# fully recreatable, low-risk.
estimate_safe_cleanup_bytes() {
    sum_bytes \
        "$(xcode_derived_data_bytes 2>/dev/null)" \
        "$(flutter_pub_cache_bytes 2>/dev/null)" \
        "$(gradle_caches_bytes 2>/dev/null)" \
        "$(cocoapods_cache_bytes 2>/dev/null)" \
        "$(node_cache_bytes 2>/dev/null)" \
        "$(bun_cache_bytes 2>/dev/null)" \
        "$(brew_cache_bytes 2>/dev/null)"
}

# estimate_risky_cleanup_bytes
# Sum of every item this tool only ever removes after typing DELETE -
# not casually recreatable, or simply large and disruptive to lose.
estimate_risky_cleanup_bytes() {
    sum_bytes \
        "$(xcode_devicesupport_bytes 2>/dev/null)" \
        "$(xcode_archives_bytes 2>/dev/null)" \
        "$(simulator_devices_bytes 2>/dev/null)" \
        "$(android_avd_bytes 2>/dev/null)" \
        "$(docker_reclaimable_bytes 2>/dev/null)"
}

# estimate_reclaimable_bytes
# A best-effort, read-only estimate of what quick clean + the guided
# cleanup menus could recover. This is informational only; it never
# implies anything will be deleted automatically.
estimate_reclaimable_bytes() {
    sum_bytes "$(estimate_safe_cleanup_bytes)" "$(estimate_risky_cleanup_bytes)"
}
