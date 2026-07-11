#!/bin/bash
# devclean uninstaller.
#
# Removes only what install.sh created:
#   - the /usr/local/bin/devclean or /opt/homebrew/bin/devclean symlink,
#     but only if it still points into this install directory
#   - the marked alias block in ~/.zshrc, if present
#
# Never deletes logs/, reports/, or this source directory unless you pass
# --purge-logs / --purge-reports explicitly, and even then asks first.

set -u
set -o pipefail

# uninstall.sh is always run directly from within the repo (never
# symlinked - only the `devclean` executable itself is symlinked onto
# PATH), so a plain physical-path resolution is enough.
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

PURGE_LOGS=0
PURGE_REPORTS=0
for arg in "$@"; do
    case "$arg" in
        --purge-logs) PURGE_LOGS=1 ;;
        --purge-reports) PURGE_REPORTS=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

echo "devclean uninstaller"
echo "Install directory: $SCRIPT_DIR"
echo

for bindir in /opt/homebrew/bin /usr/local/bin; do
    link="$bindir/devclean"
    if [ -L "$link" ]; then
        target="$(readlink "$link")"
        if [ "$target" = "$SCRIPT_DIR/devclean" ]; then
            printf 'Remove symlink %s -> %s ? [y/N]: ' "$link" "$target"
            read -r reply < /dev/tty 2>/dev/null || read -r reply
            case "$reply" in
                y|Y|yes|YES|Yes)
                    rm -f "$link"
                    echo "  Removed $link"
                    ;;
                *)
                    echo "  Skipped $link"
                    ;;
            esac
        else
            echo "Found $link but it points elsewhere ($target) - leaving it alone."
        fi
    fi
done
echo

ZSHRC="$HOME/.zshrc"
MARKER_START="# >>> devclean installer >>>"
MARKER_END="# <<< devclean installer <<<"
if [ -f "$ZSHRC" ] && grep -qF "$MARKER_START" "$ZSHRC" 2>/dev/null; then
    echo "Found a devclean alias block in $ZSHRC."
    printf 'Remove it? [y/N]: '
    read -r reply < /dev/tty 2>/dev/null || read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes)
            backup="${ZSHRC}.devclean-backup.$(date +%Y%m%d-%H%M%S)"
            cp "$ZSHRC" "$backup"
            echo "  Backed up $ZSHRC to $backup"
            awk -v s="$MARKER_START" -v e="$MARKER_END" '
                $0 == s {skip=1; next}
                $0 == e {skip=0; next}
                !skip {print}
            ' "$ZSHRC" > "${ZSHRC}.tmp.$$" && mv "${ZSHRC}.tmp.$$" "$ZSHRC"
            echo "  Removed the alias block from $ZSHRC."
            ;;
        *)
            echo "  Skipped."
            ;;
    esac
else
    echo "No devclean alias block found in $ZSHRC."
fi
echo

if [ "$PURGE_LOGS" -eq 1 ] && [ -d "$SCRIPT_DIR/logs" ]; then
    printf 'Delete %s and all its contents? [y/N]: ' "$SCRIPT_DIR/logs"
    read -r reply < /dev/tty 2>/dev/null || read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes)
            rm -rf -- "$SCRIPT_DIR/logs"
            echo "  Removed $SCRIPT_DIR/logs"
            ;;
        *) echo "  Skipped." ;;
    esac
fi

if [ "$PURGE_REPORTS" -eq 1 ] && [ -d "$SCRIPT_DIR/reports" ]; then
    printf 'Delete %s and all its contents? [y/N]: ' "$SCRIPT_DIR/reports"
    read -r reply < /dev/tty 2>/dev/null || read -r reply
    case "$reply" in
        y|Y|yes|YES|Yes)
            rm -rf -- "$SCRIPT_DIR/reports"
            echo "  Removed $SCRIPT_DIR/reports"
            ;;
        *) echo "  Skipped." ;;
    esac
fi

echo
echo "Uninstall complete."
echo "The devclean source directory has not been touched:"
echo "  $SCRIPT_DIR"
echo "Remove it yourself if you no longer want it."
