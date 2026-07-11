#!/bin/bash
# "devclean update" - check the latest GitHub Release. Strictly read-only:
# it never downloads, installs, or modifies anything, and it never runs
# an update automatically. It only reports what it finds.

# _update_extract_json_field <json> <field>
# Minimal, dependency-free extraction of a top-level "field": "value" pair
# from a GitHub API response. Good enough for the flat string fields we
# need (tag_name, html_url, published_at) without requiring jq.
_update_extract_json_field() {
    local json="$1" field="$2"
    printf '%s' "$json" \
        | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -n1 \
        | sed -E "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\\1/"
}

# _update_status <current_version> <latest_tag>
# Pure version-comparison decision, no network - kept separate from
# update_check_command so it can be unit tested in isolation. Returns one
# of: update_available | up_to_date | ahead_of_release.
_update_status() {
    local current="$1" latest="${2#v}"
    if version_gt "$latest" "$current"; then
        echo "update_available"
    elif version_gt "$current" "$latest"; then
        echo "ahead_of_release"
    else
        echo "up_to_date"
    fi
}

update_check_command() {
    section_header "Check for updates"
    print_kv "Current version:" "$DEVCLEAN_VERSION"
    print_kv "Repository:" "$DEVCLEAN_REPO"
    echo

    if ! command_exists curl; then
        echo "curl is required to check for updates and was not found on PATH."
        log_warn "update check: curl not found"
        return 1
    fi

    # Deliberately no -f here: a plain 404/403 is a valid, expected response
    # we handle explicitly below via the captured HTTP status. -f would
    # make curl fail before we ever see the body or status for those cases.
    local api_url response http_code body
    api_url="https://api.github.com/repos/${DEVCLEAN_REPO}/releases/latest"
    response="$(curl -sS -L -w '\n%{http_code}' --max-time 10 "$api_url" 2>/dev/null)"
    local curl_rc=$?

    if [ "$curl_rc" -ne 0 ] || [ -z "$response" ]; then
        echo "Could not reach GitHub (network unavailable or the request failed)."
        log_warn "update check failed: curl exit code $curl_rc"
        return 1
    fi

    http_code="$(printf '%s' "$response" | tail -n1)"
    body="$(printf '%s' "$response" | sed '$d')"

    case "$http_code" in
        200)
            ;;
        403|429)
            echo "GitHub API rate limit exceeded. Try again later."
            log_warn "update check rate-limited (HTTP $http_code)"
            return 1
            ;;
        404)
            echo "No published release found for $DEVCLEAN_REPO yet."
            log_warn "update check: no release (HTTP 404)"
            return 1
            ;;
        *)
            echo "GitHub returned an unexpected response (HTTP $http_code)."
            log_warn "update check: unexpected HTTP $http_code"
            return 1
            ;;
    esac

    local latest_tag release_url published_at
    latest_tag="$(_update_extract_json_field "$body" "tag_name")"
    release_url="$(_update_extract_json_field "$body" "html_url")"
    published_at="$(_update_extract_json_field "$body" "published_at")"

    if [ -z "$latest_tag" ]; then
        echo "Could not parse the latest release information."
        log_warn "update check: failed to parse tag_name"
        return 1
    fi

    print_kv "Latest version:" "$latest_tag"
    [ -n "$release_url" ] && print_kv "Release URL:" "$release_url"
    # published_at is ISO 8601, e.g. "2026-07-11T19:19:50Z" - the date
    # portion is all we show; omitted entirely if GitHub didn't provide it.
    [ -n "$published_at" ] && print_kv "Published:" "${published_at%%T*}"
    echo

    case "$(_update_status "$DEVCLEAN_VERSION" "$latest_tag")" in
        update_available)
            printf '%bUpdate available: %s -> %s%b\n' "$COLOR_YELLOW" "$DEVCLEAN_VERSION" "$latest_tag" "$COLOR_RESET"
            echo "devclean never updates itself automatically - visit the release URL above to update by hand."
            ;;
        ahead_of_release)
            echo "You are running a newer development version than the latest published release."
            print_kv "Installed:" "$DEVCLEAN_VERSION"
            print_kv "Latest published release:" "$latest_tag"
            ;;
        up_to_date)
            echo "You are running the latest version."
            ;;
    esac
}
