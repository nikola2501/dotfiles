#!/usr/bin/env bash
# Links the Cyanide - Matrix theme into VS Code and points user settings at it.
#
# Idempotent. Safe to run again after a `git pull`.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/vscode/cyanide-matrix"
ext_dir="$HOME/.vscode/extensions"
link="$ext_dir/nikola.cyanide-matrix-0.1.0"

case "$(uname -s)" in
  Darwin) settings="$HOME/Library/Application Support/Code/User/settings.json" ;;
  *)      settings="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json" ;;
esac

mkdir -p "$ext_dir"
if [ -L "$link" ] || [ -e "$link" ]; then
  rm -rf "$link"
fi
ln -s "$src" "$link"
echo "linked $link -> $src"

if ! command -v jq >/dev/null; then
  echo "jq not found; set workbench.colorTheme to 'Cyanide - Matrix' by hand" >&2
  exit 0
fi

mkdir -p "$(dirname "$settings")"
[ -s "$settings" ] || echo '{}' > "$settings"

# Sublime: font_size 11 * ui_scale 1.5 (Preferences (OSX)) ~= 16px.
tmp="$(mktemp)"
jq --indent 4 '. + {
  "workbench.colorTheme": "Cyanide - Matrix",
  "editor.fontFamily": "Monaco, Menlo, monospace",
  "editor.fontSize": 16,
  "editor.semanticHighlighting.enabled": "configuredByTheme"
}' "$settings" > "$tmp" && mv "$tmp" "$settings"
echo "updated $settings"
