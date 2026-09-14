#!/usr/bin/env bash
# Links the Cyanide - Matrix theme into VS Code and/or VSCodium and points user settings at it.
#
# Idempotent. Safe to run again after a `git pull`.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/vscode/cyanide-matrix"
# Each target: <extensions dir>|<settings.json>. VSCodium and VS Code keep
# separate trees, so install into whichever editors are present.
targets=()
if command -v code >/dev/null || [ -d "$HOME/.vscode" ]; then
  case "$(uname -s)" in
    Darwin) targets+=("$HOME/.vscode/extensions|$HOME/Library/Application Support/Code/User/settings.json") ;;
    *)      targets+=("$HOME/.vscode/extensions|${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json") ;;
  esac
fi
if command -v codium >/dev/null || [ -d "$HOME/.vscode-oss" ]; then
  case "$(uname -s)" in
    Darwin) targets+=("$HOME/.vscode-oss/extensions|$HOME/Library/Application Support/VSCodium/User/settings.json") ;;
    *)      targets+=("$HOME/.vscode-oss/extensions|${XDG_CONFIG_HOME:-$HOME/.config}/VSCodium/User/settings.json") ;;
  esac
fi
if [ "${#targets[@]}" -eq 0 ]; then
  echo "neither code nor codium found" >&2
  exit 1
fi

for t in "${targets[@]}"; do
  ext_dir="${t%%|*}"
  settings="${t#*|}"
  link="$ext_dir/nikola.cyanide-matrix-0.1.0"

  mkdir -p "$ext_dir"
  if [ -L "$link" ] || [ -e "$link" ]; then
    rm -rf "$link"
  fi
  ln -s "$src" "$link"
  echo "linked $link -> $src"

  if ! command -v jq >/dev/null; then
    echo "jq not found; set workbench.colorTheme to 'Cyanide - Matrix' by hand" >&2
    continue
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
done
