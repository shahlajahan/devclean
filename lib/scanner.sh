#!/bin/bash
# Top-level "devclean scan" orchestration and the reclaimable-space estimate
# shown in the interactive menu header. Read-only - no deletions happen here.

scan_command() {
    menu_banner_if_needed
    disk_scan
    general_locations_scan
    xcode_scan
    simulator_scan
    flutter_scan
    gradle_scan
    android_scan
    cocoapods_scan
    node_scan
    docker_scan
    brew_scan
    whatsapp_scan

    section_header "Summary"
    print_kv "Estimated reclaimable:" "$(human_size "$(estimate_reclaimable_bytes)")"
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

# estimate_reclaimable_bytes
# A best-effort, read-only estimate of what quick clean + the guided
# cleanup menus could recover. This is informational only; it never
# implies anything will be deleted automatically.
estimate_reclaimable_bytes() {
    local total=0
    total="$(sum_bytes \
        "$(xcode_derived_data_bytes 2>/dev/null)" \
        "$(xcode_devicesupport_bytes 2>/dev/null)" \
        "$(xcode_archives_bytes 2>/dev/null)" \
        "$(flutter_pub_cache_bytes 2>/dev/null)" \
        "$(gradle_caches_bytes 2>/dev/null)" \
        "$(cocoapods_cache_bytes 2>/dev/null)" \
        "$(node_cache_bytes 2>/dev/null)" \
        "$(brew_cache_bytes 2>/dev/null)" \
        "$(docker_reclaimable_bytes 2>/dev/null)" \
    )"
    echo "$total"
}
