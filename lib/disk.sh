#!/bin/bash
# Disk-level and general-location reporting.
# This module never deletes anything - it only measures.

disk_scan() {
    section_header "Disk"
    local total used free
    total="$(disk_total_bytes)"
    used="$(disk_used_bytes)"
    free="$(disk_free_bytes)"
    print_kv "Total:" "$(human_size "$total")"
    print_kv "Used:" "$(human_size "$used")"
    print_kv "Free:" "$(human_size "$free")"
}

general_locations_scan() {
    section_header "General locations"
    local p bytes
    for p in "${GENERAL_SCAN_PATHS[@]}"; do
        if [ "$p" = "/" ]; then
            # A recursive du of the whole boot volume can take many minutes
            # and cross into every other user's files. df already gives us
            # the used-space figure instantly and accurately.
            print_kv "/ (used, via df):" "$(human_size "$(disk_used_bytes)")"
            continue
        fi
        if [ -e "$p" ]; then
            bytes="$(path_size_bytes "$p")"
            print_kv "$p" "$(human_size "$bytes")"
        else
            print_kv "$p" "(not found)"
        fi
    done
}
