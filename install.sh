#!/usr/bin/env bash
# install.sh — set this machine up from these dotfiles. Linux and macOS.
#
#   ./install.sh              symlink helix config, .zshrc and the bin/ scripts
#   ./install.sh --helix      also clone+build the Helix fork and enable `hxp`
#   ./install.sh --uninstall  remove the symlinks and restore the newest backups
#   ./install.sh --dry-run    show what would happen, change nothing
#   ./install.sh --force      replace differing files without asking
#
# Everything is symlinked, never copied — so editing ~/.zshrc edits this repo and
# the two can never drift apart. Any real file already in the way is backed up
# first, never overwritten.

set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")" && pwd)
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
HELIX_FORK="${HELIX_FORK:-$HOME/repos/me/helix-plugin}"
FORK_URL="https://github.com/nikola2501/helix-plugin.git"
OS=$(uname -s)
STAMP=$(date +%Y%m%d-%H%M%S)
DO_HELIX=0; UNINSTALL=0; DRY=0; FORCE=0

while [ $# -gt 0 ]; do
  case $1 in
    --helix)     DO_HELIX=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run)   DRY=1 ;;
    --force)     FORCE=1 ;;
    -h|--help)   sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

say()  { printf '  %s\n' "$*"; }
run()  { if [ "$DRY" -eq 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# Point $2 at $1, backing up whatever real file is in the way.
link() {
  local src=$1 dst=$2
  [ -e "$src" ] || { say "SKIP  $dst  (missing in repo: ${src#$DOTFILES/})"; return; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    say "ok    $dst"; return
  fi
  # A real file that differs from the repo version is the dangerous case: linking
  # would silently swap in whatever the repo last had. Ask before doing that.
  if [ -e "$dst" ] && [ ! -L "$dst" ] && ! cmp -s "$dst" "$src"; then
    local n; n=$(diff "$dst" "$src" 2>/dev/null | grep -c '^[<>]' || true)
    say "DIFFERS  $dst"
    say "         the copy here differs from ${src#$DOTFILES/} by $n lines"
    if [ "$FORCE" -eq 1 ]; then
      say "         --force: replacing (the current file is backed up)"
    elif [ "$DRY" -eq 1 ]; then
      say "         would ask before replacing"
    elif [ -t 0 ]; then
      printf '         replace it? it is backed up either way [y/N] '
      local ans; read -r ans
      case $ans in [yY]*) ;; *) say "         kept $dst as it is"; return ;; esac
    else
      say "         SKIPPED (not a terminal). Compare them first:"
      say "           diff $dst $src"
      say "         then re-run with --force, or copy yours into the repo:"
      say "           cp $dst $src"
      return
    fi
  fi
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run mv "$dst" "$dst.bak-$STAMP"
    say "moved $dst -> $(basename "$dst").bak-$STAMP"
  fi
  run ln -s "$src" "$dst"
  say "link  $dst -> ${src#$DOTFILES/}"
}

unlink_one() {
  local dst=$1
  if [ -L "$dst" ]; then
    run rm "$dst"
    local newest
    newest=$(ls -1dt "$dst".bak-* 2>/dev/null | head -1 || true)
    if [ -n "$newest" ]; then run mv "$newest" "$dst"; say "restored $dst from $(basename "$newest")"
    else say "removed  $dst (no backup to restore)"; fi
  fi
}

# ---------------------------------------------------------------- uninstall
if [ "$UNINSTALL" -eq 1 ]; then
  echo; echo "  removing symlinks"; echo
  unlink_one "$CONFIG_HOME/helix/config.toml"
  unlink_one "$CONFIG_HOME/helix/languages.toml"
  unlink_one "$HOME/.zshrc"
  unlink_one "$BIN/hx-make"
  unlink_one "$BIN/hx-harpoon"
  echo; say "done"; echo
  exit 0
fi

echo
echo "  dotfiles -> $HOME   ($OS)"
[ "$DRY" -eq 1 ] && echo "  DRY RUN — nothing will change"
echo

# ---------------------------------------------------------------- helix config
link "$DOTFILES/helix/config.toml"    "$CONFIG_HOME/helix/config.toml"
link "$DOTFILES/helix/languages.toml" "$CONFIG_HOME/helix/languages.toml"

# ---------------------------------------------------------------- zsh
# The Linux and macOS shells genuinely differ (paths, oh-my-zsh, app locations),
# so each OS gets its own file and the shared parts live in zsh/common.zsh.
ZSHRC="$DOTFILES/zsh/zshrc.$OS"
if [ -e "$ZSHRC" ]; then
  link "$ZSHRC" "$HOME/.zshrc"
else
  say "SKIP  ~/.zshrc  (no zsh/zshrc.$OS in this repo yet)"
  say "      create it with:  cp ~/.zshrc $DOTFILES/zsh/zshrc.$OS"
fi

# ---------------------------------------------------------------- scripts
link "$DOTFILES/bin/hx-make"    "$BIN/hx-make"
link "$DOTFILES/bin/hx-harpoon" "$BIN/hx-harpoon"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) say "note  $BIN is not on PATH yet — zsh/common.zsh adds it, open a new shell" ;;
esac

# ---------------------------------------------------------------- helix fork
if [ "$DO_HELIX" -eq 1 ]; then
  echo
  command -v cargo >/dev/null 2>&1 || { echo "  error: cargo not found — install Rust first" >&2; exit 1; }
  command -v git   >/dev/null 2>&1 || { echo "  error: git not found" >&2; exit 1; }
  if [ ! -d "$HELIX_FORK/.git" ]; then
    say "cloning the Helix fork into $HELIX_FORK"
    run git clone "$FORK_URL" "$HELIX_FORK"
    run git -C "$HELIX_FORK" remote add upstream https://github.com/helix-editor/helix.git
  else
    say "using the existing checkout at $HELIX_FORK"
  fi
  if [ "$DRY" -eq 0 ]; then
    say "building (a few minutes)..."
    ( cd "$HELIX_FORK" && cargo build --profile opt )
    say "fetching and building tree-sitter grammars (this is the slow part)..."
    ( cd "$HELIX_FORK" && HELIX_RUNTIME="$HELIX_FORK/runtime" ./target/opt/hx --grammar fetch >/dev/null )
    ( cd "$HELIX_FORK" && HELIX_RUNTIME="$HELIX_FORK/runtime" ./target/opt/hx --grammar build >/dev/null )
    say "built $HELIX_FORK/target/opt/hx  —  the hxp alias picks it up automatically"
  fi
fi

# ---------------------------------------------------------------- verify
echo
if [ "$DRY" -eq 0 ]; then
  ok=1
  [ -L "$CONFIG_HOME/helix/config.toml" ] || ok=0
  [ -x "$BIN/hx-make" ] || ok=0
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import tomllib,sys; tomllib.load(open('$DOTFILES/helix/config.toml','rb'))" \
      || { echo "  WARNING: helix/config.toml is not valid TOML"; ok=0; }
  fi
  [ "$ok" -eq 1 ] && say "self-test passed"
fi

cat <<'EOT'

  Done. Open a new shell.

    hxp                 the Helix fork (after --helix)
    <space>m  A-ret     build into the quickfix buffer, jump to an error
    <space>za A-1..A-9  pin a file, jump to a pin

  See README.md for the full key list.

EOT
