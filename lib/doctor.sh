#!/bin/bash
# "devclean doctor" - development environment health checks.
# Never installs or modifies anything; purely diagnostic.

_DOCTOR_WARNINGS=0
_DOCTOR_ERRORS=0
_DOCTOR_SCORE_EARNED=0
_DOCTOR_SCORE_POSSIBLE=0
_DOCTOR_RECOMMENDATIONS=()
_DOCTOR_REC_HINTS=()
_DOCTOR_OPTIONAL_MISSING=()

# _doctor_fix_hint <name>
# A short, known fix for a subset of checks - pure lookup, no side
# effects, so it's unit testable. Empty output means "no known hint",
# and callers only print a Fix line when this returns non-empty.
_doctor_fix_hint() {
    case "$1" in
        "Xcode.app") echo "Install Xcode from the App Store" ;;
        "xcode-select path") echo "Run: xcode-select --install" ;;
        "xcrun") echo "Install Xcode command line tools: xcode-select --install" ;;
        "Flutter") echo "Install from https://flutter.dev" ;;
        "Dart") echo "Installed automatically with the Flutter SDK" ;;
        "Java") echo "Install a JDK, e.g. brew install openjdk" ;;
        "Android SDK") echo "Open Android Studio -> SDK Manager" ;;
        "adb") echo "Ensure Android platform-tools are on PATH" ;;
        "Node") echo "Install from https://nodejs.org or via Homebrew" ;;
        "npm") echo "Installed automatically with Node.js" ;;
        "Git") echo "Install Xcode command line tools: xcode-select --install" ;;
        *) echo "" ;;
    esac
}

_doctor_line() {
    # _doctor_line <status> <name> <detail>
    local status="$1" name="$2" detail="${3:-}"
    local color label

    case "$status" in
        OK)
            color="$COLOR_GREEN"; label="OK      "
            _DOCTOR_SCORE_EARNED=$((_DOCTOR_SCORE_EARNED + 2))
            _DOCTOR_SCORE_POSSIBLE=$((_DOCTOR_SCORE_POSSIBLE + 2))
            ;;
        WARNING)
            color="$COLOR_YELLOW"; label="WARNING "
            _DOCTOR_WARNINGS=$((_DOCTOR_WARNINGS + 1))
            _DOCTOR_SCORE_EARNED=$((_DOCTOR_SCORE_EARNED + 1))
            _DOCTOR_SCORE_POSSIBLE=$((_DOCTOR_SCORE_POSSIBLE + 2))
            _DOCTOR_RECOMMENDATIONS+=("$name: $detail")
            _DOCTOR_REC_HINTS+=("$(_doctor_fix_hint "$name")")
            ;;
        ERROR)
            color="$COLOR_RED"; label="ERROR   "
            _DOCTOR_ERRORS=$((_DOCTOR_ERRORS + 1))
            _DOCTOR_SCORE_POSSIBLE=$((_DOCTOR_SCORE_POSSIBLE + 2))
            _DOCTOR_RECOMMENDATIONS+=("$name: $detail")
            _DOCTOR_REC_HINTS+=("$(_doctor_fix_hint "$name")")
            ;;
        OPTIONAL)
            color="$COLOR_DIM"; label="OPTIONAL"
            _DOCTOR_OPTIONAL_MISSING+=("$name")
            ;;
        *)
            color="$COLOR_RESET"; label="$status"
            ;;
    esac

    printf '  %b%-8s%b %-28s %s\n' "$color" "$label" "$COLOR_RESET" "$name" "$detail"
}

_doctor_cmd_version() {
    # Best-effort single-line version string for a command.
    local cmd="$1"
    shift
    command_exists "$cmd" || return 1
    "$cmd" "$@" 2>/dev/null | head -n1
}

# _doctor_score <earned> <possible>
# Pure integer-percentage calculation, kept separate from _doctor_line so
# it can be unit tested without running the full doctor sweep.
_doctor_score() {
    local earned="${1:-0}" possible="${2:-0}"
    if [ "$possible" -le 0 ]; then
        echo 100
        return 0
    fi
    awk -v e="$earned" -v p="$possible" 'BEGIN { printf "%d", (e / p) * 100 }'
}

doctor_command() {
    _DOCTOR_WARNINGS=0
    _DOCTOR_ERRORS=0
    _DOCTOR_SCORE_EARNED=0
    _DOCTOR_SCORE_POSSIBLE=0
    _DOCTOR_RECOMMENDATIONS=()
    _DOCTOR_REC_HINTS=()
    _DOCTOR_OPTIONAL_MISSING=()

    section_header "Developer doctor"

    local macos_v
    macos_v="$(_report_macos_version 2>/dev/null || sw_vers -productVersion 2>/dev/null)"
    _doctor_line OK "macOS version" "$macos_v"

    local free
    free="$(disk_free_bytes)"
    if [ "$free" -lt 2147483648 ]; then
        _doctor_line ERROR "Disk free space" "$(human_size "$free") free (critically low)"
    elif [ "$free" -lt 16106127360 ]; then
        _doctor_line WARNING "Disk free space" "$(human_size "$free") free"
    else
        _doctor_line OK "Disk free space" "$(human_size "$free") free"
    fi

    if [ -d "/Applications/Xcode.app" ]; then
        _doctor_line OK "Xcode.app" "/Applications/Xcode.app"
    else
        _doctor_line WARNING "Xcode.app" "not found in /Applications (command line tools may still be installed)"
    fi

    local xcode_select_path
    xcode_select_path="$(xcode-select -p 2>/dev/null)"
    if [ -n "$xcode_select_path" ]; then
        _doctor_line OK "xcode-select path" "$xcode_select_path"
    else
        _doctor_line ERROR "xcode-select path" "not configured"
    fi

    if command_exists xcrun; then
        _doctor_line OK "xcrun" "$(command -v xcrun)"
    else
        _doctor_line ERROR "xcrun" "not found"
    fi

    if command_exists flutter; then
        _doctor_line OK "Flutter" "$(_doctor_cmd_version flutter --version)"
    else
        _doctor_line ERROR "Flutter" "not found on PATH"
    fi

    if command_exists dart; then
        _doctor_line OK "Dart" "$(_doctor_cmd_version dart --version)"
    else
        _doctor_line ERROR "Dart" "not found on PATH"
    fi

    if command_exists java; then
        _doctor_line OK "Java" "$(java -version 2>&1 | head -n1)"
    else
        _doctor_line ERROR "Java" "not found on PATH"
    fi

    if [ -d "$ANDROID_HOME_DIR" ]; then
        _doctor_line OK "Android SDK" "$ANDROID_HOME_DIR"
    else
        _doctor_line ERROR "Android SDK" "not found at $ANDROID_HOME_DIR"
    fi

    if command_exists adb; then
        _doctor_line OK "adb" "$(command -v adb)"
    else
        _doctor_line ERROR "adb" "not found on PATH"
    fi

    if command_exists pod; then
        _doctor_line OK "CocoaPods" "$(_doctor_cmd_version pod --version)"
    else
        _doctor_line ERROR "CocoaPods" "not found on PATH (gem install cocoapods)"
    fi

    if command_exists ruby; then
        _doctor_line OK "Ruby" "$(_doctor_cmd_version ruby --version)"
    else
        _doctor_line ERROR "Ruby" "not found on PATH"
    fi

    if command_exists node; then
        _doctor_line OK "Node" "$(_doctor_cmd_version node --version)"
    else
        _doctor_line ERROR "Node" "not found on PATH"
    fi

    if command_exists npm; then
        _doctor_line OK "npm" "$(_doctor_cmd_version npm --version)"
    else
        _doctor_line ERROR "npm" "not found on PATH"
    fi

    if command_exists yarn; then
        _doctor_line OK "yarn" "$(_doctor_cmd_version yarn --version)"
    else
        _doctor_line OPTIONAL "yarn" "not installed"
    fi

    if command_exists pnpm; then
        _doctor_line OK "pnpm" "$(_doctor_cmd_version pnpm --version)"
    else
        _doctor_line OPTIONAL "pnpm" "not installed"
    fi

    if command_exists bun; then
        _doctor_line OK "Bun" "$(_doctor_cmd_version bun --version)"
    else
        _doctor_line OPTIONAL "Bun" "not installed"
    fi

    if command_exists firebase; then
        _doctor_line OK "Firebase CLI" "$(_doctor_cmd_version firebase --version)"
    else
        _doctor_line OPTIONAL "Firebase CLI" "not found (npm install -g firebase-tools)"
    fi

    if command_exists git; then
        _doctor_line OK "Git" "$(_doctor_cmd_version git --version)"
    else
        _doctor_line ERROR "Git" "not found on PATH"
    fi

    if command_exists docker; then
        if docker_available 2>/dev/null; then
            _doctor_line OK "Docker" "installed, daemon running"
        else
            _doctor_line WARNING "Docker" "installed, but daemon is not running"
        fi
    else
        _doctor_line OPTIONAL "Docker" "not installed"
    fi

    if brew_available; then
        _doctor_line OK "Homebrew" "$(_doctor_cmd_version brew --version)"
    else
        _doctor_line OPTIONAL "Homebrew" "not installed"
    fi

    if command_exists code; then
        _doctor_line OK "VS Code (code command)" "$(command -v code)"
    else
        _doctor_line OPTIONAL "VS Code (code command)" "not found (Shell Command: Install 'code' in PATH)"
    fi

    echo
    print_kv "Warnings:" "$_DOCTOR_WARNINGS"
    print_kv "Errors:" "$_DOCTOR_ERRORS"

    section_header "Developer Environment"
    echo "$(_doctor_score "$_DOCTOR_SCORE_EARNED" "$_DOCTOR_SCORE_POSSIBLE") / 100"

    if [ "${#_DOCTOR_RECOMMENDATIONS[@]}" -gt 0 ] || [ "${#_DOCTOR_OPTIONAL_MISSING[@]}" -gt 0 ]; then
        echo
        echo "Recommendations"

        if [ "${#_DOCTOR_RECOMMENDATIONS[@]}" -gt 0 ]; then
            echo
            echo "Required"
            local idx=0 rec hint
            for rec in "${_DOCTOR_RECOMMENDATIONS[@]}"; do
                echo "  - $rec"
                hint="${_DOCTOR_REC_HINTS[$idx]:-}"
                [ -n "$hint" ] && echo "      Fix: $hint"
                idx=$((idx + 1))
            done
        fi

        if [ "${#_DOCTOR_OPTIONAL_MISSING[@]}" -gt 0 ]; then
            echo
            echo "Optional tools"
            local opt
            for opt in "${_DOCTOR_OPTIONAL_MISSING[@]}"; do
                echo "  - $opt"
            done
        fi
    fi
}
