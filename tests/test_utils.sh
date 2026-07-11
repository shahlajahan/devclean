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

echo
echo "test_utils.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
