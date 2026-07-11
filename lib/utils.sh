#!/bin/bash
# Core reusable utility functions shared by every devclean module.
# Compatible with the macOS system bash (3.2) - no bash4-only features.

# ---------------------------------------------------------------------------
# Basic predicates
# ---------------------------------------------------------------------------

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Path safety
# ---------------------------------------------------------------------------

# is_dangerous_path <path>
# Returns 0 (true) if the path must never be passed to a destructive
# operation. Errs heavily on the side of caution: only paths that are
# absolute, non-empty, and clearly nested inside the user's home directory
# (or another explicitly-approved location) are considered safe.
is_dangerous_path() {
    local p="$1"

    [ -z "$p" ] && return 0

    case "$p" in
        /|/Users|/System|/Applications|/Library|/private|/bin|/sbin|/usr|/etc|/var|/opt|/tmp|/root|/Volumes)
            return 0
            ;;
    esac

    [ "$p" = "$HOME" ] && return 0
    [ "$p" = "${HOME}/" ] && return 0
    [ "$p" = "$HOME/Library" ] && return 0
    [ "$p" = "$HOME/Documents" ] && return 0
    [ "$p" = "$HOME/Desktop" ] && return 0
    [ "$p" = "$HOME/Downloads" ] && return 0
    [ "$p" = "$HOME/Pictures" ] && return 0

    # Must be absolute.
    case "$p" in
        /*) ;;
        *) return 0 ;;
    esac

    # Must live under $HOME - devclean never deletes outside the user's home.
    case "$p" in
        "$HOME"/*) ;;
        *) return 0 ;;
    esac

    # Reject paths that are just $HOME plus trailing slashes/whitespace.
    local trimmed="${p%/}"
    [ "$trimmed" = "$HOME" ] && return 0
    [ -z "$trimmed" ] && return 0

    return 1
}

# safe_remove_path <path>
# Validates the path and, unless DRY_RUN, removes it recursively.
# Always goes through run_or_dry so dry-run/logging semantics are uniform.
safe_remove_path() {
    local target="$1"

    if is_dangerous_path "$target"; then
        log_error "Refused to remove unsafe path: $target"
        printf '%bRefused to remove unsafe path: %s%b\n' "$COLOR_RED" "$target" "$COLOR_RESET" >&2
        return 1
    fi

    if [ ! -e "$target" ]; then
        log_info "Nothing to remove (already absent): $target"
        return 0
    fi

    run_or_dry "remove $target" rm -rf -- "$target"
}

# ---------------------------------------------------------------------------
# Sizes
# ---------------------------------------------------------------------------

# path_size_bytes <path>
# Prints total size in bytes, 0 if the path does not exist or is unreadable.
path_size_bytes() {
    local target="$1"
    local kb

    if [ -z "$target" ] || [ ! -e "$target" ]; then
        echo 0
        return 0
    fi

    kb="$(du -sk "$target" 2>/dev/null | awk '{print $1}')"
    if [ -z "$kb" ]; then
        echo 0
        return 0
    fi
    echo $(( kb * 1024 ))
}

# human_size <bytes>
# Human-readable size (B, KB, MB, GB, TB), one decimal place.
human_size() {
    local bytes="${1:-0}"
    case "$bytes" in
        ''|*[!0-9]*) bytes=0 ;;
    esac
    awk -v b="$bytes" 'BEGIN {
        split("B KB MB GB TB PB", units, " ")
        size = b
        i = 1
        while (size >= 1024 && i < 6) {
            size = size / 1024
            i++
        }
        if (units[i] == "B") {
            printf "%d %s", size, units[i]
        } else {
            printf "%.1f %s", size, units[i]
        }
    }'
}

sum_bytes() {
    # sum_bytes b1 b2 b3 ...
    local total=0
    local n
    for n in "$@"; do
        case "$n" in
            ''|*[!0-9]*) continue ;;
        esac
        total=$(( total + n ))
    done
    echo "$total"
}

# ---------------------------------------------------------------------------
# Disk
# ---------------------------------------------------------------------------

disk_total_bytes() {
    df -k / | awk 'NR==2 {print $2 * 1024}'
}

disk_used_bytes() {
    df -k / | awk 'NR==2 {print $3 * 1024}'
}

disk_free_bytes() {
    df -k / | awk 'NR==2 {print $4 * 1024}'
}

# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------

timestamp() {
    date +%Y%m%d-%H%M%S
}

iso_timestamp() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ---------------------------------------------------------------------------
# JSON
# ---------------------------------------------------------------------------

# json_escape <string>
# Escapes a string for safe inclusion inside a JSON double-quoted value.
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="$(printf '%s' "$s" | awk '{gsub(/\t/,"\\t"); print}')"
    s="$(printf '%s' "$s" | tr '\n' ' ' | tr '\r' ' ')"
    printf '%s' "$s"
}

json_str() {
    # json_str <value> -> "escaped value"
    printf '"%s"' "$(json_escape "$1")"
}

# ---------------------------------------------------------------------------
# Prompts / confirmation
# ---------------------------------------------------------------------------

# confirm_yes_no <prompt>
# Low-risk confirmation. Defaults to "No". Returns 0 for yes.
confirm_yes_no() {
    local prompt="$1"
    local reply

    if [ "${DEVCLEAN_ASSUME_NO:-0}" -eq 1 ]; then
        return 1
    fi

    printf '%b%s [y/N]: %b' "$COLOR_YELLOW" "$prompt" "$COLOR_RESET"
    read -r reply < /dev/tty 2>/dev/null || read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# confirm_delete_word <prompt>
# High-impact confirmation. User must type DELETE exactly.
confirm_delete_word() {
    local prompt="$1"
    local reply

    if [ "${DEVCLEAN_ASSUME_NO:-0}" -eq 1 ]; then
        return 1
    fi

    printf '%b%s%b\n' "$COLOR_RED" "$prompt" "$COLOR_RESET"
    printf 'Type %bDELETE%b to continue: ' "$COLOR_BOLD" "$COLOR_RESET"
    read -r reply < /dev/tty 2>/dev/null || read -r reply
    [ "$reply" = "DELETE" ]
}

press_enter_to_continue() {
    printf '%bPress Enter to continue...%b' "$COLOR_DIM" "$COLOR_RESET"
    read -r _ < /dev/tty 2>/dev/null || read -r _
}

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

# run_or_dry <description> <command...>
# Central gate for every action that changes state on disk. When DRY_RUN=1
# the command is never executed - only described and logged.
run_or_dry() {
    local description="$1"
    shift

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '%b[DRY-RUN]%b %s\n' "$COLOR_CYAN" "$COLOR_RESET" "$description"
        log_info "[DRY-RUN] would run: $description ($*)"
        return 0
    fi

    log_info "RUN: $description ($*)"
    if "$@"; then
        log_info "OK: $description"
        return 0
    else
        local rc=$?
        log_error "FAILED ($rc): $description"
        return "$rc"
    fi
}

print_kv() {
    # print_kv <label> <value>
    printf '  %-38s %s\n' "$1" "$2"
}

section_header() {
    printf '\n%b%b%s%b\n' "$COLOR_BOLD" "$COLOR_BLUE" "$1" "$COLOR_RESET"
    printf '%b-------------------------------------------%b\n' "$COLOR_DIM" "$COLOR_RESET"
}
