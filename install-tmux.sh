#!/usr/bin/env bash
# install-tmux.sh — set up tmux from these dotfiles. Linux and macOS.
#
#   ./install-tmux.sh              link ~/.tmux.conf and tmux-keys, install tpm
#                                  and the plugins
#   ./install-tmux.sh --dry-run    show what would happen, change nothing
#   ./install-tmux.sh --force      replace a differing ~/.tmux.conf without asking
#   ./install-tmux.sh --uninstall  remove the link, restore the backup
#
# ~/.tmux.conf is symlinked, so editing it edits this repo. A real file in the
# way is backed up as .tmux.conf.bak-<timestamp> first, and one that differs
# from the repo's is never replaced without asking.
#
# Plugins are NOT vendored. tpm is cloned into ~/.tmux/plugins/tpm and installs
# the @plugin lines of tmux.conf from GitHub, so the first run needs a network
# connection. A running tmux server reloads the config; already open windows
# keep their numbers.

set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")" && pwd)
SRC="$DOTFILES/tmux/tmux.conf"
DST="$HOME/.tmux.conf"
KEYS_SRC="$DOTFILES/bin/tmux-keys"
KEYS_DST="$HOME/.local/bin/tmux-keys"      # the C-a ? popup, see tmux.conf
TPM="$HOME/.tmux/plugins/tpm"
TPM_URL=https://github.com/tmux-plugins/tpm
STAMP=$(date +%Y%m%d-%H%M%S)
DRY=0; FORCE=0; UNINSTALL=0

while [ $# -gt 0 ]; do
  case $1 in
    --dry-run)   DRY=1 ;;
    --force)     FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)   sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

say() { printf '  %s\n' "$*"; }
run() { if [ "$DRY" -eq 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# Returns 1 when the file in the way was kept, so the caller can stop.
link() {
  local src=$1 dst=$2
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then say "ok    $dst"; return; fi
  if [ -e "$dst" ] && [ ! -L "$dst" ] && ! cmp -s "$dst" "$src"; then
    local n; n=$(diff "$dst" "$src" 2>/dev/null | grep -c '^[<>]' || true)
    say "DIFFERS  $dst  ($n lines vs the repo's copy)"
    if [ "$FORCE" -eq 1 ]; then say "         --force: replacing (backed up)"
    elif [ "$DRY" -eq 1 ]; then say "         would ask before replacing"
    elif [ -t 0 ]; then
      printf '         replace it? it is backed up either way [y/N] '
      local a; read -r a; case $a in [yY]*) ;; *) say "         kept"; return 1 ;; esac
    else
      say "         SKIPPED (not a terminal). Compare, then --force, or copy yours in:"
      say "           cp \"$dst\" \"$src\""
      return 1
    fi
  fi
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run mv "$dst" "$dst.bak-$STAMP"; say "moved $dst -> $(basename "$dst").bak-$STAMP"
  fi
  run ln -s "$src" "$dst"
  say "link  $dst"
}

# ---------------------------------------------------------------- uninstall
if [ "$UNINSTALL" -eq 1 ]; then
  echo; echo "  removing the tmux config links"; echo
  for pair in "$SRC|$DST" "$KEYS_SRC|$KEYS_DST"; do
    src=${pair%|*}; dst=${pair#*|}
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      run rm "$dst"
      newest=$(ls -1dt "$dst".bak-* 2>/dev/null | head -1 || true)
      if [ -n "$newest" ]; then run mv "$newest" "$dst"; say "restored $dst"
      else say "removed  $dst"; fi
    else
      say "not ours  $dst"
    fi
  done
  say "left alone  $HOME/.tmux/plugins — delete it by hand if you want it gone"
  echo; say "done"; echo; exit 0
fi

echo
echo "  tmux dotfiles -> $DST   ($(uname -s))"
[ "$DRY" -eq 1 ] && echo "  DRY RUN — nothing will change"
echo

# ---------------------------------------------------------------- link config
if ! link "$SRC" "$DST"; then
  echo; say "~/.tmux.conf is not the repo's — plugins not installed"; echo
  exit 1
fi
link "$KEYS_SRC" "$KEYS_DST" || true

# ---------------------------------------------------------------- plugins
if ! command -v tmux >/dev/null || ! command -v git >/dev/null; then
  echo; say "tmux or git is missing — install both and re-run for the plugins"; echo
  exit 0
fi

if [ -d "$TPM" ]; then say "ok    $TPM"
else run git clone -q --depth 1 "$TPM_URL" "$TPM"; say "clone $TPM"; fi

if [ "$DRY" -eq 1 ]; then
  say "[dry-run] install the @plugin lines of tmux.conf through tpm"
else
  # tpm reads its plugin list from a server that has loaded this config. A
  # running one is reloaded; otherwise a detached session starts one with it.
  TEMP=""
  if tmux has-session 2>/dev/null; then tmux source-file "$DST"
  else TEMP="dotfiles-tpm-$$"; tmux new-session -d -s "$TEMP"; fi
  "$TPM/bin/install_plugins" | sed 's/^/  /'
  if [ -n "$TEMP" ]; then tmux kill-session -t "$TEMP"
  else tmux source-file "$DST"; say "reloaded the running tmux server"; fi
fi

echo
echo "  Done. The prefix is Ctrl+a; Ctrl+a ? shows the keys."
echo
