#!/bin/bash
# Session logging. Every run of devclean writes a timestamped log file to
# $DEVCLEAN_HOME/logs/. Logs never contain file contents - only paths,
# actions, sizes, and status.

LOG_DIR="${DEVCLEAN_HOME:-.}/logs"
SESSION_LOG="${LOG_DIR}/devclean-$(timestamp).log"

logger_init() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    {
        echo "==================================================="
        echo "devclean session started: $(iso_timestamp)"
        echo "command: devclean ${DEVCLEAN_ARGS:-}"
        echo "dry_run: ${DRY_RUN:-0}"
        echo "user: $(whoami 2>/dev/null)"
        echo "==================================================="
    } >> "$SESSION_LOG" 2>/dev/null
}

_log_write() {
    local level="$1"
    shift
    printf '[%s] [%s] %s\n' "$(iso_timestamp)" "$level" "$*" >> "$SESSION_LOG" 2>/dev/null
}

log_info() {
    _log_write "INFO" "$*"
}

log_warn() {
    _log_write "WARN" "$*"
    printf '%bWARN:%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*" >&2
}

log_error() {
    _log_write "ERROR" "$*"
    printf '%bERROR:%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

log_action() {
    # log_action <status> <path> <bytes>
    _log_write "ACTION" "status=$1 path=$2 bytes=${3:-0}"
}

logger_prune_old() {
    # Remove devclean's own log files older than N days (used by quick clean).
    local days="${1:-30}"
    [ -d "$LOG_DIR" ] || return 0
    find "$LOG_DIR" -type f -name 'devclean-*.log' -mtime "+${days}" -print 2>/dev/null
}
