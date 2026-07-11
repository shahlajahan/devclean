#!/bin/bash
# devclean installer.
#
# What this does, in order:
#   1. Makes the devclean executables runnable.
#   2. Creates the logs/ and reports/ directories.
#   3. Tries to symlink `devclean` onto PATH at /usr/local/bin or
#      /opt/homebrew/bin (whichever is writable, no sudo).
#   4. If neither is writable, offers (with confirmation) to add a single
#      clearly-marked alias line to ~/.zshrc, after backing it up.
#
# This script never uses sudo and never silently modifies your shell
# configuration - every change is announced and, for the shell config,
# confirmed first.

set -u
set -o pipefail

# install.sh is always run directly from within the repo (never symlinked -
# only the `devclean` executable itself is symlinked onto PATH), so a plain
# physical-path resolution is enough; no need for a symlink-following loop.
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/colors.sh"

echo "devclean installer"
echo "Install directory: $SCRIPT_DIR"
echo

echo "1) Making executables runnable..."
chmod +x "$SCRIPT_DIR/devclean" "$SCRIPT_DIR/devclean.sh" \
         "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/uninstall.sh" 2>/dev/null
echo "   done."

echo "2) Creating logs/ and reports/ directories..."
mkdir -p "$SCRIPT_DIR/logs" "$SCRIPT_DIR/reports"
echo "   $SCRIPT_DIR/logs"
echo "   $SCRIPT_DIR/reports"
echo

# ---------------------------------------------------------------------------
# 3) Try a writable bin directory on PATH - no sudo, ever.
# ---------------------------------------------------------------------------
TARGET_BIN=""
if [ "$(uname -m)" = "arm64" ] && [ -d /opt/homebrew/bin ] && [ -w /opt/homebrew/bin ]; then
    TARGET_BIN="/opt/homebrew/bin"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    TARGET_BIN="/usr/local/bin"
fi

installed_symlink=0
if [ -n "$TARGET_BIN" ]; then
    echo "3) Found a writable directory on PATH: $TARGET_BIN"
    local_link="$TARGET_BIN/devclean"

    if [ -L "$local_link" ] && [ "$(readlink "$local_link")" = "$SCRIPT_DIR/devclean" ]; then
        echo "   $local_link already points here. Nothing to do."
        installed_symlink=1
    else
        if [ -e "$local_link" ]; then
            echo "   $local_link already exists and points elsewhere:"
            echo "     $(readlink "$local_link" 2>/dev/null || echo "(not a symlink)")"
            printf '   Overwrite it to point to this install? [y/N]: '
            read -r reply < /dev/tty 2>/dev/null || read -r reply
        else
            printf '   Create symlink %s -> %s/devclean ? [y/N]: ' "$local_link" "$SCRIPT_DIR"
            read -r reply < /dev/tty 2>/dev/null || read -r reply
        fi
        case "$reply" in
            y|Y|yes|YES|Yes)
                ln -sf "$SCRIPT_DIR/devclean" "$local_link"
                echo "   Installed symlink: $local_link -> $SCRIPT_DIR/devclean"
                installed_symlink=1
                ;;
            *)
                echo "   Skipped symlink installation."
                ;;
        esac
    fi
else
    echo "3) Neither /opt/homebrew/bin nor /usr/local/bin is writable without sudo."
fi
echo

# ---------------------------------------------------------------------------
# 4) Fall back to a shell alias, only if the symlink step didn't succeed.
# ---------------------------------------------------------------------------
if [ "$installed_symlink" -eq 0 ]; then
    echo "4) Falling back to a shell alias in ~/.zshrc"
    ZSHRC="$HOME/.zshrc"
    MARKER_START="# >>> devclean installer >>>"
    MARKER_END="# <<< devclean installer <<<"

    if [ -f "$ZSHRC" ] && grep -qF "$MARKER_START" "$ZSHRC" 2>/dev/null; then
        echo "   An alias block already exists in $ZSHRC. Leaving it as-is."
    else
        echo "   This will add the following lines to $ZSHRC:"
        echo "     $MARKER_START"
        echo "     alias devclean=\"$SCRIPT_DIR/devclean\""
        echo "     $MARKER_END"
        printf '   Proceed? [y/N]: '
        read -r reply < /dev/tty 2>/dev/null || read -r reply
        case "$reply" in
            y|Y|yes|YES|Yes)
                if [ -f "$ZSHRC" ]; then
                    backup="${ZSHRC}.devclean-backup.$(date +%Y%m%d-%H%M%S)"
                    cp "$ZSHRC" "$backup"
                    echo "   Backed up existing $ZSHRC to $backup"
                fi
                {
                    echo ""
                    echo "$MARKER_START"
                    echo "alias devclean=\"$SCRIPT_DIR/devclean\""
                    echo "$MARKER_END"
                } >> "$ZSHRC"
                echo "   Added alias to $ZSHRC."
                echo "   Run 'source ~/.zshrc' or open a new terminal to use it."
                ;;
            *)
                echo "   Skipped. You can still run devclean directly:"
                echo "     $SCRIPT_DIR/devclean"
                ;;
        esac
    fi
fi

echo
echo "Installation summary:"
echo "  Install directory: $SCRIPT_DIR"
echo "  Logs:               $SCRIPT_DIR/logs"
echo "  Reports:            $SCRIPT_DIR/reports"
if [ "$installed_symlink" -eq 1 ]; then
    echo "  On PATH as:         devclean"
else
    echo "  Run directly with:  $SCRIPT_DIR/devclean"
fi
echo
echo "Get started: devclean --help"
