#!/bin/bash
# End-to-end smoke tests for devclean.
# Run: bash tests/smoke_test.sh
#
# These tests only ever touch a throwaway fixture directory created and
# destroyed by this script - never real user data - and never run a real
# (non-dry-run) destructive command.

set -u
set -o pipefail

_resolve_dir() {
    local src="$1"
    while [ -h "$src" ]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
        src="$(readlink "$src")"
        case "$src" in
            /*) ;;
            *) src="$dir/$src" ;;
        esac
    done
    cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd
}

TESTS_DIR="$(_resolve_dir "${BASH_SOURCE[0]:-$0}")"
DEVCLEAN_HOME="$(cd -P "$TESTS_DIR/.." >/dev/null 2>&1 && pwd)"
DEVCLEAN_BIN="$DEVCLEAN_HOME/devclean"

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  ok - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL - $1"; }

echo "== Module sourcing =="
for mod in colors utils logger ui disk scanner xcode simulator flutter \
           gradle android cocoapods node docker brew whatsapp cleaner \
           report doctor; do
    modpath="$DEVCLEAN_HOME/lib/${mod}.sh"
    if [ ! -f "$modpath" ]; then
        fail "module exists: $mod"
        continue
    fi
    if bash -n "$modpath" 2>/tmp/devclean_test_err; then
        ok "syntax check: $mod"
    else
        fail "syntax check: $mod ($(cat /tmp/devclean_test_err))"
    fi
done

echo
echo "== Top-level scripts syntax =="
for f in "$DEVCLEAN_HOME/devclean" "$DEVCLEAN_HOME/devclean.sh" \
         "$DEVCLEAN_HOME/config.sh" "$DEVCLEAN_HOME/install.sh" \
         "$DEVCLEAN_HOME/uninstall.sh"; do
    if bash -n "$f" 2>/tmp/devclean_test_err; then
        ok "syntax check: $(basename "$f")"
    else
        fail "syntax check: $(basename "$f") ($(cat /tmp/devclean_test_err))"
    fi
done

echo
echo "== --help / --version =="
out="$("$DEVCLEAN_BIN" --help 2>&1)"
if echo "$out" | grep -q "USAGE"; then
    ok "--help prints usage"
else
    fail "--help prints usage"
fi

out="$("$DEVCLEAN_BIN" --version 2>&1)"
if echo "$out" | grep -qE "devclean version [0-9]+\.[0-9]+\.[0-9]+"; then
    ok "--version prints a semantic version"
else
    fail "--version prints a semantic version"
fi

echo
echo "== devclean scan runs cleanly =="
if "$DEVCLEAN_BIN" scan >/tmp/devclean_test_scan.log 2>&1; then
    ok "scan exits 0"
else
    fail "scan exits 0"
fi
if grep -q "Estimated reclaimable" /tmp/devclean_test_scan.log; then
    ok "scan prints a summary"
else
    fail "scan prints a summary"
fi

echo
echo "== devclean doctor runs cleanly (missing optional tools handled) =="
if "$DEVCLEAN_BIN" doctor >/tmp/devclean_test_doctor.log 2>&1; then
    ok "doctor exits 0"
else
    fail "doctor exits 0"
fi
if grep -qE "OK|WARNING|MISSING|OPTIONAL" /tmp/devclean_test_doctor.log; then
    ok "doctor prints status labels"
else
    fail "doctor prints status labels"
fi

echo
echo "== devclean report generates valid TXT + JSON =="
before_count=$(find "$DEVCLEAN_HOME/reports" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if "$DEVCLEAN_BIN" report >/tmp/devclean_test_report.log 2>&1; then
    ok "report exits 0"
else
    fail "report exits 0"
fi
after_count=$(find "$DEVCLEAN_HOME/reports" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
if [ "$after_count" -gt "$before_count" ]; then
    ok "report created a new JSON file"
else
    fail "report created a new JSON file"
fi

latest_json="$(find "$DEVCLEAN_HOME/reports" -name '*.json' 2>/dev/null | sort | tail -n1)"
if [ -n "$latest_json" ]; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$latest_json" 2>/tmp/devclean_test_json_err; then
            ok "JSON report is valid (python3 json.load)"
        else
            fail "JSON report is valid ($(cat /tmp/devclean_test_json_err))"
        fi
    else
        first_char="$(head -c1 "$latest_json")"
        last_char="$(tail -c2 "$latest_json" | head -c1)"
        if [ "$first_char" = "{" ] && [ "$last_char" = "}" ]; then
            ok "JSON report has balanced outer braces (basic check, python3 unavailable)"
        else
            fail "JSON report has balanced outer braces"
        fi
    fi
    latest_txt="${latest_json%.json}.txt"
    if [ -f "$latest_txt" ]; then
        ok "matching TXT report exists"
    else
        fail "matching TXT report exists"
    fi
else
    fail "found a generated JSON report"
fi

echo
echo "== --dry-run never deletes a fixture =="
FIXTURE_DIR="$HOME/.devclean_smoke_fixture_$$"
mkdir -p "$FIXTURE_DIR/subdir"
echo "throwaway" > "$FIXTURE_DIR/subdir/file.txt"

(
    DEVCLEAN_HOME="$DEVCLEAN_HOME"
    export DEVCLEAN_HOME
    DRY_RUN=1
    export DRY_RUN
    # shellcheck disable=SC1091
    source "$DEVCLEAN_HOME/lib/colors.sh"
    # shellcheck disable=SC1091
    source "$DEVCLEAN_HOME/lib/utils.sh"
    # shellcheck disable=SC1091
    source "$DEVCLEAN_HOME/lib/logger.sh"
    logger_init >/dev/null 2>&1
    safe_remove_path "$FIXTURE_DIR" >/tmp/devclean_test_dryrun.log 2>&1
)

if [ -d "$FIXTURE_DIR" ] && [ -f "$FIXTURE_DIR/subdir/file.txt" ]; then
    ok "dry-run left the fixture untouched"
else
    fail "dry-run left the fixture untouched"
fi
if grep -q "DRY-RUN" /tmp/devclean_test_dryrun.log; then
    ok "dry-run printed a [DRY-RUN] notice"
else
    fail "dry-run printed a [DRY-RUN] notice"
fi

rm -rf -- "$FIXTURE_DIR"

echo
echo "== devclean --dry-run scan (combined flag + command) =="
if "$DEVCLEAN_BIN" --dry-run scan >/tmp/devclean_test_dryscan.log 2>&1; then
    ok "--dry-run scan exits 0"
else
    fail "--dry-run scan exits 0"
fi

echo
echo "== Unknown command is rejected =="
if "$DEVCLEAN_BIN" totally-not-a-command >/tmp/devclean_test_unknown.log 2>&1; then
    fail "unknown command exits non-zero"
else
    ok "unknown command exits non-zero"
fi

rm -f /tmp/devclean_test_err /tmp/devclean_test_scan.log /tmp/devclean_test_doctor.log \
      /tmp/devclean_test_report.log /tmp/devclean_test_json_err /tmp/devclean_test_dryrun.log \
      /tmp/devclean_test_dryscan.log /tmp/devclean_test_unknown.log

echo
echo "smoke_test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
