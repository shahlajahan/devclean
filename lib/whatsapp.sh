#!/bin/bash
# WhatsApp storage audit.
#
# Safety model: devclean NEVER deletes anything here. WhatsApp Desktop
# stores message databases and media in this container, and there is no
# reliable way for a generic tool to know what is safe to lose. This module
# only measures and, on request, reveals the folder in Finder.

whatsapp_container_bytes() {
    path_size_bytes "$WHATSAPP_CONTAINER_DIR"
}

whatsapp_scan() {
    section_header "WhatsApp (audit only - nothing is ever deleted here)"
    if [ ! -d "$WHATSAPP_CONTAINER_DIR" ]; then
        print_kv "Status:" "WhatsApp Desktop container not found"
        return 0
    fi

    print_kv "Total ($WHATSAPP_CONTAINER_DIR):" "$(human_size "$(whatsapp_container_bytes)")"

    local name path
    for name in Message Media Logs; do
        path="$(_whatsapp_find_subdir "$name")"
        if [ -n "$path" ]; then
            print_kv "  $name:" "$(human_size "$(path_size_bytes "$path")")"
        fi
    done
}

_whatsapp_find_subdir() {
    # Case-insensitive search for a subdirectory by name, a few levels deep.
    find "$WHATSAPP_CONTAINER_DIR" -maxdepth 4 -iname "$1" -type d -print 2>/dev/null | head -n1
}

whatsapp_detail() {
    if [ ! -d "$WHATSAPP_CONTAINER_DIR" ]; then
        echo "WhatsApp Desktop container not found at:"
        echo "  $WHATSAPP_CONTAINER_DIR"
        echo "WhatsApp Desktop may not be installed, or has never been signed in."
        return 0
    fi

    echo "Container: $WHATSAPP_CONTAINER_DIR"
    echo "Total:     $(human_size "$(whatsapp_container_bytes)")"
    echo
    echo "Breakdown:"
    local name path bytes any=0
    for name in Message Media Logs; do
        path="$(_whatsapp_find_subdir "$name")"
        if [ -n "$path" ]; then
            any=1
            bytes="$(path_size_bytes "$path")"
            printf '  %-10s %-60s %s\n' "$name:" "$path" "$(human_size "$bytes")"
        fi
    done
    [ "$any" -eq 0 ] && echo "  (no Message/Media/Logs subfolders were found by name - layout may differ by version)"
    echo
    echo "devclean never deletes WhatsApp data automatically or otherwise."
    echo "Desktop WhatsApp data (message databases, media) is never assumed"
    echo "safe to delete. If you want to free space, do so manually and"
    echo "deliberately from within the WhatsApp application, after confirming"
    echo "your chat history is backed up."
}

whatsapp_open_finder() {
    if [ ! -d "$WHATSAPP_CONTAINER_DIR" ]; then
        echo "WhatsApp Desktop container not found; nothing to open."
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        echo "[DRY-RUN] would run: open \"$WHATSAPP_CONTAINER_DIR\""
        return 0
    fi
    run_or_dry "open WhatsApp container in Finder" open "$WHATSAPP_CONTAINER_DIR"
}

whatsapp_menu() {
    local choice
    while true; do
        section_header "WhatsApp storage audit"
        cat <<'EOF'
  1) Show detailed breakdown
  2) Open folder in Finder
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) whatsapp_detail ;;
            2) whatsapp_open_finder ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}
