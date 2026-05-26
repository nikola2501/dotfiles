#!/usr/bin/env bash
# Symlink every file in dotfiles/sublime/User/ into Sublime Text's
# Packages/User/ directory.
#
# - Dry-run by default. Pass --apply to actually make changes.
# - Detects macOS vs Linux automatically.
# - Idempotent: skips files that are already symlinked to the right target.
# - Backs up existing real files to *.bak.<timestamp> before replacing them.
# - Skips .DS_Store and .git.
#
# IMPORTANT: dotfiles is treated as the source of truth. Before running with
# --apply on a machine where you've been editing Sublime Text directly,
# review the dry-run output and copy any newer live files into
# dotfiles/sublime/User/ first; otherwise this script will replace them with
# (probably stale) dotfiles versions. The .bak files are your safety net but
# don't rely on them.

set -euo pipefail

APPLY=0
case "${1:-}" in
    --apply) APPLY=1 ;;
    --dry-run|"") APPLY=0 ;;
    -h|--help)
        sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown arg: $1 (use --apply, --dry-run, or --help)" >&2
        exit 2
        ;;
esac

SRC_DIR="$(cd "$(dirname "$0")/User" && pwd)"

case "$(uname -s)" in
    Darwin)
        DST_DIR="$HOME/Library/Application Support/Sublime Text/Packages/User"
        ;;
    Linux)
        DST_DIR="$HOME/.config/sublime-text/Packages/User"
        if [ ! -d "$DST_DIR" ] && [ -d "$HOME/.config/sublime-text-3/Packages/User" ]; then
            DST_DIR="$HOME/.config/sublime-text-3/Packages/User"
        fi
        ;;
    *)
        echo "unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ ! -d "$DST_DIR" ]; then
    echo "Sublime Text User folder not found: $DST_DIR" >&2
    echo "Install Sublime Text and launch it once before running this script." >&2
    exit 1
fi

if [ "$APPLY" -eq 0 ]; then
    echo "DRY-RUN mode. No changes will be made. Pass --apply to actually link."
else
    echo "APPLY mode. Real changes incoming."
fi
echo "linking from $SRC_DIR"
echo "          to $DST_DIR"
echo

ts="$(date +%Y%m%d-%H%M%S)"
would_link=0; up_to_date=0; would_backup=0

shopt -s dotglob nullglob
for src in "$SRC_DIR"/*; do
    name="$(basename "$src")"
    [ "$name" = ".DS_Store" ] && continue
    [ "$name" = ".git" ] && continue
    # don't try to install the install script itself
    [ "$name" = "install.sh" ] && continue

    dst="$DST_DIR/$name"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        up_to_date=$((up_to_date + 1))
        continue
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        backup="$dst.bak.$ts"
        if [ "$APPLY" -eq 1 ]; then
            mv "$dst" "$backup"
        fi
        echo "  REPLACE: $name  (would back up real file to $(basename "$backup"))"
        would_backup=$((would_backup + 1))
    else
        echo "  LINK:    $name"
    fi

    if [ "$APPLY" -eq 1 ]; then
        ln -s "$src" "$dst"
    fi
    would_link=$((would_link + 1))
done

echo
if [ "$APPLY" -eq 0 ]; then
    echo "summary: $would_link would change ($would_backup would replace existing), $up_to_date already linked. Re-run with --apply to commit."
else
    echo "summary: $would_link changed ($would_backup replaced), $up_to_date already linked."
fi
