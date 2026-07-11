#!/bin/bash
# Docker cleanup. Entirely optional - only activates if the `docker` CLI is
# present and the daemon responds. Never prunes without confirmation, and
# every prune action is treated as high-impact (requires typing DELETE).

# _devclean_run_with_timeout <seconds> <command...>
# Portable timeout using only bash builtins (no GNU coreutils dependency).
_devclean_run_with_timeout() {
    local secs="$1"
    shift
    "$@" &
    local cmd_pid=$!
    (
        sleep "$secs" 2>/dev/null
        kill -TERM "$cmd_pid" 2>/dev/null
    ) &
    local watcher_pid=$!
    local rc=0
    wait "$cmd_pid" 2>/dev/null || rc=$?
    kill "$watcher_pid" 2>/dev/null
    wait "$watcher_pid" 2>/dev/null
    return "$rc"
}

docker_available() {
    command_exists docker || return 1
    _devclean_run_with_timeout 5 docker info >/dev/null 2>&1
}

_docker_size_to_bytes() {
    local s="$1"
    [ -z "$s" ] && { echo 0; return 0; }
    awk -v s="$s" 'BEGIN {
        if (match(s, /^[0-9.]+/)) {
            num = substr(s, RSTART, RLENGTH)
        } else {
            num = 0
        }
        unit = substr(s, RSTART + RLENGTH)
        gsub(/^[ \t]+|[ \t]+$/, "", unit)
        mult = 1
        if (unit == "kB" || unit == "KB") mult = 1024
        else if (unit == "MB") mult = 1024 * 1024
        else if (unit == "GB") mult = 1024 * 1024 * 1024
        else if (unit == "TB") mult = 1024 * 1024 * 1024 * 1024
        printf "%d", num * mult
    }'
}

docker_reclaimable_bytes() {
    docker_available || { echo 0; return 0; }
    local total=0 type size reclaim val
    while IFS='|' read -r type size reclaim; do
        [ -z "$reclaim" ] && continue
        val="${reclaim%% (*}"
        total=$(( total + $(_docker_size_to_bytes "$val") ))
    done < <(_devclean_run_with_timeout 8 docker system df --format '{{.Type}}|{{.Size}}|{{.Reclaimable}}' 2>/dev/null)
    echo "$total"
}

docker_scan() {
    section_header "Docker"
    if ! command_exists docker; then
        print_kv "Status:" "not installed"
        return 0
    fi
    if ! docker_available; then
        print_kv "Status:" "installed, but daemon is not reachable"
        return 0
    fi
    print_kv "Status:" "running"
    echo
    _devclean_run_with_timeout 8 docker system df 2>/dev/null | sed 's/^/  /'
}

docker_menu() {
    local choice
    if ! command_exists docker; then
        echo "Docker is not installed. Skipping Docker cleanup."
        return 0
    fi
    if ! docker_available; then
        echo "Docker is installed but the daemon is not running or not reachable."
        return 0
    fi

    while true; do
        section_header "Docker cleanup"
        _devclean_run_with_timeout 8 docker system df 2>/dev/null | sed 's/^/  /'
        echo
        cat <<'EOF'
  1) Prune stopped containers
  2) Prune dangling images
  3) Prune all unused images
  4) Prune build cache
  5) Prune unused volumes (can delete data - review carefully)
  6) Full system prune (containers + networks + images + build cache)
  0) Back
EOF
        printf 'Select an option: '
        read -r choice < /dev/tty 2>/dev/null || read -r choice
        case "$choice" in
            1) _docker_prune "stopped containers" "This removes all stopped containers." container prune -f ;;
            2) _docker_prune "dangling images" "This removes images not referenced by any container." image prune -f ;;
            3) _docker_prune "all unused images" "This removes ALL images not used by an existing container, not just dangling ones." image prune -a -f ;;
            4) _docker_prune "build cache" "This removes the Docker builder cache." builder prune -f ;;
            5) _docker_prune "unused volumes" "This removes volumes not used by any container. If a stopped container you plan to restart owns one, its data is lost permanently." volume prune -f ;;
            6) _docker_prune "full system prune" "This removes stopped containers, unused networks, dangling images, and build cache." system prune -f ;;
            0) break ;;
            *) echo "Unknown option: $choice" ;;
        esac
        echo
    done
}

_docker_prune() {
    local label="$1" explanation="$2"
    shift 2

    echo "Action:      docker $*"
    echo "Explanation: $explanation"
    echo "Note:        Anything removed here must be rebuilt or re-pulled to use again."
    echo

    if confirm_delete_word "Prune $label now?"; then
        run_or_dry "docker $*" docker "$@"
        log_action "pruned" "docker:$label" 0
    else
        echo "Skipped."
        log_action "skipped" "docker:$label" 0
    fi
}
