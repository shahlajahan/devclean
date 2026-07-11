#!/bin/bash
# Unit tests for lib/utils.sh helpers.
# Run: bash tests/test_utils.sh

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
export DEVCLEAN_HOME
DRY_RUN=0
export DRY_RUN
DEVCLEAN_ASSUME_NO=1
export DEVCLEAN_ASSUME_NO

# shellcheck disable=SC1091
source "$DEVCLEAN_HOME/lib/colors.sh"
# shellcheck disable=SC1091
source "$DEVCLEAN_HOME/lib/utils.sh"
# shellcheck disable=SC1091
source "$DEVCLEAN_HOME/lib/logger.sh"
logger_init >/dev/null 2>&1
# shellcheck disable=SC1091
source "$DEVCLEAN_HOME/lib/ui.sh"
# shellcheck disable=SC1091
source "$DEVCLEAN_HOME/lib/doctor.sh"
# shellcheck disable=SC1091
source "$DEVCLEAN_HOME/lib/update.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        echo "  ok - $desc"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL - $desc (expected [$expected], got [$actual])"
    fi
}

assert_true() {
    local desc="$1"; shift
    if "$@"; then
        PASS=$((PASS + 1))
        echo "  ok - $desc"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL - $desc"
    fi
}

assert_false() {
    local desc="$1"; shift
    if ! "$@"; then
        PASS=$((PASS + 1))
        echo "  ok - $desc"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL - $desc"
    fi
}

echo "== human_size =="
assert_eq "0 bytes" "0 B" "$(human_size 0)"
assert_eq "1024 bytes -> 1.0 KB" "1.0 KB" "$(human_size 1024)"
assert_eq "1048576 bytes -> 1.0 MB" "1.0 MB" "$(human_size 1048576)"
assert_eq "non-numeric input treated as 0" "0 B" "$(human_size abc)"

echo "== sum_bytes =="
assert_eq "sums integers" "6144" "$(sum_bytes 1024 2048 3072)"
assert_eq "ignores garbage" "1024" "$(sum_bytes 1024 abc "")"

echo "== json_escape / json_str =="
assert_eq "escapes quotes" '\"hi\"' "$(json_escape '"hi"')"
assert_eq "json_str wraps in quotes" '"a/b"' "$(json_str 'a/b')"

echo "== timestamp =="
ts="$(timestamp)"
case "$ts" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9])
        PASS=$((PASS + 1)); echo "  ok - timestamp format" ;;
    *)
        FAIL=$((FAIL + 1)); echo "  FAIL - timestamp format ($ts)" ;;
esac

echo "== is_dangerous_path =="
assert_true "empty path is dangerous" is_dangerous_path ""
assert_true "root is dangerous" is_dangerous_path "/"
assert_true "HOME is dangerous" is_dangerous_path "$HOME"
assert_true "HOME/Library is dangerous" is_dangerous_path "$HOME/Library"
assert_true "relative path is dangerous" is_dangerous_path "some/relative/path"
assert_true "path outside HOME is dangerous" is_dangerous_path "/Applications/Foo.app"
assert_false "nested HOME path is safe" is_dangerous_path "$HOME/Library/Developer/Xcode/DerivedData"

echo "== safe_remove_path refuses dangerous targets =="
assert_false "refuses to remove HOME" safe_remove_path "$HOME"
assert_false "refuses to remove /" safe_remove_path "/"
assert_false "refuses to remove empty path" safe_remove_path ""

echo "== path_size_bytes =="
assert_eq "missing path is 0 bytes" "0" "$(path_size_bytes "/no/such/path/$$")"

echo "== confirm_yes_no / confirm_delete_word default to No when non-interactive =="
assert_false "confirm_yes_no denies under DEVCLEAN_ASSUME_NO" confirm_yes_no "test prompt"
assert_false "confirm_delete_word denies under DEVCLEAN_ASSUME_NO" confirm_delete_word "test prompt"

echo "== version_gt (v1.1.0) =="
assert_true "1.2.0 > 1.1.0" version_gt "1.2.0" "1.1.0"
assert_false "1.1.0 not > 1.1.0 (equal)" version_gt "1.1.0" "1.1.0"
assert_true "1.1.10 > 1.1.9" version_gt "1.1.10" "1.1.9"
assert_true "1.2 > 1.1.9 (short form treated as 1.2.0)" version_gt "1.2" "1.1.9"
assert_false "1.0.9 not > 1.1.0" version_gt "1.0.9" "1.1.0"
assert_false "1.1.0 not > 1.2.0" version_gt "1.1.0" "1.2.0"

echo "== progress_bar (v1.1.0) =="
assert_eq "0/10 renders 0%, no fill" "X [....................]   0%" "$(progress_bar 0 10 "X")"
assert_eq "5/10 renders 50%, half fill" "X [##########..........]  50%" "$(progress_bar 5 10 "X")"
assert_eq "10/10 renders 100%, full fill" "X [####################] 100%" "$(progress_bar 10 10 "X")"

echo "== _doctor_score (v1.1.0) =="
assert_eq "all OK -> 100" "100" "$(_doctor_score 10 10)"
assert_eq "half credit -> 50" "50" "$(_doctor_score 5 10)"
assert_eq "nothing scored -> 100" "100" "$(_doctor_score 0 0)"
assert_eq "matches a real doctor run (30 earned / 34 possible)" "88" "$(_doctor_score 30 34)"

echo "== multi_select_prompt (v1.1.0, fed via piped stdin) =="
result="$(printf '2\nc\n' | multi_select_prompt "Test" "Alpha" "Beta" "Gamma" 2>/dev/null)"
assert_eq "toggling 2 then confirming returns index 2" " 2" "$result"

if printf 'q\n' | multi_select_prompt "Test" "Alpha" "Beta" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1)); echo "  FAIL - 'q' cancels (expected non-zero exit)"
else
    PASS=$((PASS + 1)); echo "  ok - 'q' cancels (non-zero exit, nothing selected)"
fi

echo "== _update_status (polish pass) =="
assert_eq "installed < latest -> update_available" "update_available" "$(_update_status "1.0.0" "v1.2.3")"
assert_eq "installed == latest -> up_to_date" "up_to_date" "$(_update_status "1.1.0" "v1.1.0")"
assert_eq "installed > latest -> ahead_of_release (never 'up_to_date')" "ahead_of_release" "$(_update_status "1.1.0" "v1.0.0")"
assert_eq "tag without leading v still compares correctly" "up_to_date" "$(_update_status "1.1.0" "1.1.0")"

echo "== _doctor_fix_hint (polish pass) =="
assert_eq "known problem returns a hint" "Open Android Studio -> SDK Manager" "$(_doctor_fix_hint "Android SDK")"
assert_eq "unknown name returns empty (no hint shown)" "" "$(_doctor_fix_hint "Some Unknown Tool")"

echo
echo "test_utils.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
