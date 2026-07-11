#!/bin/bash
# "devclean doctor" - development environment health checks.
# Never installs or modifies anything; purely diagnostic.

_DOCTOR_WARNINGS=0
_DOCTOR_MISSING=0

_doctor_line() {
    # _doctor_line <status> <name> <detail>
    local status="$1" name="$2" detail="${3:-}"
    local color label

    case "$status" in
        OK) color="$COLOR_GREEN"; label="OK      " ;;
        WARNING) color="$COLOR_YELLOW"; label="WARNING "; _DOCTOR_WARNINGS=$((_DOCTOR_WARNINGS + 1)) ;;
        MISSING) color="$COLOR_RED"; label="MISSING "; _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1)) ;;
        OPTIONAL) color="$COLOR_DIM"; label="OPTIONAL" ;;
        *) color="$COLOR_RESET"; label="$status" ;;
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

doctor_command() {
    _DOCTOR_WARNINGS=0
    _DOCTOR_MISSING=0

    section_header "Developer doctor"

    local macos_v
    macos_v="$(_report_macos_version 2>/dev/null || sw_vers -productVersion 2>/dev/null)"
    _doctor_line OK "macOS version" "$macos_v"

    local free
    free="$(disk_free_bytes)"
    if [ "$free" -lt 5368709120 ]; then
        _doctor_line WARNING "Disk free space" "$(human_size "$free") free (low)"
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
        _doctor_line MISSING "xcode-select path" "not configured"
    fi

    if command_exists xcrun; then
        _doctor_line OK "xcrun" "$(command -v xcrun)"
    else
        _doctor_line MISSING "xcrun" "not found"
    fi

    if command_exists flutter; then
        _doctor_line OK "Flutter" "$(_doctor_cmd_version flutter --version)"
    else
        _doctor_line MISSING "Flutter" "not found on PATH"
    fi

    if command_exists dart; then
        _doctor_line OK "Dart" "$(_doctor_cmd_version dart --version)"
    else
        _doctor_line MISSING "Dart" "not found on PATH"
    fi

    if command_exists java; then
        _doctor_line OK "Java" "$(java -version 2>&1 | head -n1)"
    else
        _doctor_line MISSING "Java" "not found on PATH"
    fi

    if [ -d "$ANDROID_HOME_DIR" ]; then
        _doctor_line OK "Android SDK" "$ANDROID_HOME_DIR"
    else
        _doctor_line MISSING "Android SDK" "not found at $ANDROID_HOME_DIR"
    fi

    if command_exists adb; then
        _doctor_line OK "adb" "$(command -v adb)"
    else
        _doctor_line MISSING "adb" "not found on PATH"
    fi

    if command_exists pod; then
        _doctor_line OK "CocoaPods" "$(_doctor_cmd_version pod --version)"
    else
        _doctor_line MISSING "CocoaPods" "not found on PATH (gem install cocoapods)"
    fi

    if command_exists ruby; then
        _doctor_line OK "Ruby" "$(_doctor_cmd_version ruby --version)"
    else
        _doctor_line MISSING "Ruby" "not found on PATH"
    fi

    if command_exists node; then
        _doctor_line OK "Node" "$(_doctor_cmd_version node --version)"
    else
        _doctor_line MISSING "Node" "not found on PATH"
    fi

    if command_exists npm; then
        _doctor_line OK "npm" "$(_doctor_cmd_version npm --version)"
    else
        _doctor_line MISSING "npm" "not found on PATH"
    fi

    if command_exists firebase; then
        _doctor_line OK "Firebase CLI" "$(_doctor_cmd_version firebase --version)"
    else
        _doctor_line OPTIONAL "Firebase CLI" "not found (npm install -g firebase-tools)"
    fi

    if command_exists git; then
        _doctor_line OK "Git" "$(_doctor_cmd_version git --version)"
    else
        _doctor_line MISSING "Git" "not found on PATH"
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
    print_kv "Missing:" "$_DOCTOR_MISSING"
}
