#!/usr/bin/env bash
# install-emacs.sh — set this machine up from these dotfiles. Linux and macOS.
#
#   ./install-emacs.sh              symlink the emacs config and set up the daemon
#   ./install-emacs.sh --no-daemon  symlink the config only, skip the daemon
#   ./install-emacs.sh --uninstall  remove the symlinks, the daemon and the zsh block
#   ./install-emacs.sh --dry-run    show what would happen, change nothing
#   ./install-emacs.sh --force      replace differing files without asking
#
# Your ~/.zshrc is never replaced. The installer only appends one small marked
# block to it (aliases + EDITOR + COLORTERM) and rewrites just that block on
# re-runs. The config files are symlinked; anything real already in the way is
# backed up first, never overwritten.
#
# Packages are NOT vendored. On first start Emacs installs them from MELPA
# itself (see emacs/rc/rc.el), so the first launch needs a network connection
# and takes a few seconds. elpa/, eln-cache/, var/ and custom.el stay machine
# local and are never committed.

set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")" && pwd)
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
EMACS_DIR="$CONFIG_HOME/emacs"
OS=$(uname -s)
STAMP=$(date +%Y%m%d-%H%M%S)
UNINSTALL=0; DRY=0; FORCE=0; NO_DAEMON=0

while [ $# -gt 0 ]; do
  case $1 in
    --no-daemon) NO_DAEMON=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run)   DRY=1 ;;
    --force)     FORCE=1 ;;
    -h|--help)   sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
  if [ -e "$dst" ] && [ ! -L "$dst" ] && ! diff -rq "$dst" "$src" >/dev/null 2>&1; then
    say "DIFFERS  $dst"
    say "         differs from ${src#$DOTFILES/}"
    if [ "$FORCE" -eq 1 ]; then
      say "         --force: replacing (the current copy is backed up)"
    elif [ "$DRY" -eq 1 ]; then
      say "         would ask before replacing"
    elif [ -t 0 ]; then
      printf '         replace it? it is backed up either way [y/N] '
      local ans; read -r ans
      case $ans in [yY]*) ;; *) say "         kept $dst as it is"; return ;; esac
    else
      say "         SKIPPED (not a terminal). Compare them first:"
      say "           diff -r $dst $src"
      say "         then re-run with --force."
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

ZSHRC="$HOME/.zshrc"
BEGIN_MARK="# >>> dotfiles: emacs >>>"
END_MARK="# <<< dotfiles: emacs <<<"
PLIST="$HOME/Library/LaunchAgents/gnu.emacs.daemon.plist"
UNIT_DIR="$CONFIG_HOME/systemd/user/emacs.service.d"

# ---------------------------------------------------------------- uninstall
if [ "$UNINSTALL" -eq 1 ]; then
  echo; echo "  removing the emacs setup"; echo

  if [ "$OS" = "Darwin" ]; then
    if [ -f "$PLIST" ]; then
      run launchctl bootout "gui/$(id -u)/gnu.emacs.daemon" 2>/dev/null || true
      run rm -f "$PLIST"
      say "removed  $PLIST"
    fi
  else
    if command -v systemctl >/dev/null 2>&1; then
      run systemctl --user disable --now emacs.service 2>/dev/null || true
      say "disabled emacs.service"
    fi
    [ -f "$UNIT_DIR/dotfiles.conf" ] && { run rm -f "$UNIT_DIR/dotfiles.conf"; say "removed  $UNIT_DIR/dotfiles.conf"; }
    run systemctl --user daemon-reload 2>/dev/null || true
  fi

  unlink_one "$EMACS_DIR/init.el"
  unlink_one "$EMACS_DIR/rc"
  unlink_one "$EMACS_DIR/local"
  unlink_one "$EMACS_DIR/README.md"
  unlink_one "$EMACS_DIR/COMPILE.md"
  unlink_one "$EMACS_DIR/CHEATSHEET.md"

  if [ -f "$ZSHRC" ] && grep -qF "$BEGIN_MARK" "$ZSHRC"; then
    run cp "$ZSHRC" "$ZSHRC.bak-$STAMP"
    if [ "$DRY" -eq 0 ]; then
      awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' \
        "$ZSHRC" > "$ZSHRC.em.$$" && mv "$ZSHRC.em.$$" "$ZSHRC"
    fi
    say "removed the emacs block from ~/.zshrc (backup alongside)"
  fi

  echo
  say "your packages and state are still in $EMACS_DIR (elpa/ var/ custom.el)"
  say "delete that directory by hand if you want a clean slate"
  echo
  exit 0
fi

# ---------------------------------------------------------------- preflight
echo
echo "  dotfiles -> $HOME   ($OS)"
[ "$DRY" -eq 1 ] && echo "  DRY RUN — nothing will change"
echo

if ! command -v emacs >/dev/null 2>&1; then
  say "emacs is not installed."
  case $OS in
    Darwin) say "  brew install emacs-plus --with-native-comp   (or: brew install emacs)" ;;
    *)      say "  pacman -S emacs   /   apt install emacs   /   dnf install emacs" ;;
  esac
  exit 1
fi

EMACS_BIN=$(command -v emacs)
EMACS_VER=$("$EMACS_BIN" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
EMACS_MAJOR=${EMACS_VER%%.*}
say "emacs $EMACS_VER  ($EMACS_BIN)"
if [ "${EMACS_MAJOR:-0}" -lt 28 ]; then
  say "WARNING  this config expects Emacs 28+. Yours is $EMACS_VER."
fi

# Tools the config shells out to. Missing ones degrade one feature each,
# they do not break the config, so this only warns.
for t in git rg go gofmt make gcc; do
  command -v "$t" >/dev/null 2>&1 || say "note  '$t' not found — $(
    case $t in
      git)   echo "magit will not work" ;;
      rg)    echo "C-c s (project search) will not work" ;;
      go)    echo "go build / C-c c in Go projects" ;;
      gofmt) echo "no format-on-save for Go" ;;
      make)  echo "the default compile command is 'make'" ;;
      gcc)   echo "C compilation" ;;
    esac)"
done
echo

# ---------------------------------------------------------------- config
link "$DOTFILES/emacs/init.el"       "$EMACS_DIR/init.el"
link "$DOTFILES/emacs/rc"            "$EMACS_DIR/rc"
link "$DOTFILES/emacs/local"         "$EMACS_DIR/local"
link "$DOTFILES/emacs/README.md"     "$EMACS_DIR/README.md"
link "$DOTFILES/emacs/COMPILE.md"    "$EMACS_DIR/COMPILE.md"
link "$DOTFILES/emacs/CHEATSHEET.md" "$EMACS_DIR/CHEATSHEET.md"

# ---------------------------------------------------------------- zsh
zsh_block() {
  cat <<'BLOCK'
# >>> dotfiles: emacs >>>
# Added by dotfiles/install-emacs.sh. Edit the installer, not this block — it is
# rewritten in place on every run. Delete it by hand or with --uninstall.
#
# COLORTERM: without it Emacs assumes a 256-colour terminal and approximates the
# theme's colours (naysayer's #062329 background comes out navy #00005f).
export COLORTERM=truecolor
alias e='emacs -nw'                  # standalone instance, no daemon
alias ec='emacsclient -t -a ""'      # terminal frame on the daemon
export EDITOR='emacsclient -t -a ""'
export VISUAL="$EDITOR"
if [[ "$OSTYPE" == darwin* ]]; then
  alias emacs-restart='launchctl kickstart -k "gui/$(id -u)/gnu.emacs.daemon"'
else
  alias emacs-restart='systemctl --user restart emacs.service'
fi
# <<< dotfiles: emacs <<<
BLOCK
}

if [ "$DRY" -eq 1 ]; then
  if [ -f "$ZSHRC" ] && grep -qF "$BEGIN_MARK" "$ZSHRC"; then
    say "[dry-run] would rewrite the emacs block in $ZSHRC"
  else
    say "[dry-run] would append the emacs block to $ZSHRC"
  fi
else
  touch "$ZSHRC"
  if grep -qF "$BEGIN_MARK" "$ZSHRC"; then
    tmp="$ZSHRC.em.$$"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      $0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$ZSHRC" > "$tmp"
    awk 'BEGIN{n=0} {lines[NR]=$0} END{last=NR; while(last>0 && lines[last]~/^[ \t]*$/) last--; for(i=1;i<=last;i++) print lines[i]}' "$tmp" > "$tmp.2"
    mv "$tmp.2" "$tmp"
    { cat "$tmp"; echo; zsh_block; } > "$ZSHRC"
    rm -f "$tmp"
    say "zshrc updated the emacs block in $ZSHRC"
  else
    { echo; zsh_block; } >> "$ZSHRC"
    say "zshrc appended the emacs block to $ZSHRC (nothing else touched)"
  fi
fi

# ---------------------------------------------------------------- daemon
# The daemon keeps Emacs warm so `ec` opens instantly. It also needs its own
# environment: it is started by systemd/launchd, not by your shell, so it does
# not see anything you export in ~/.zshrc. Two things must be passed in:
#   PATH       or the daemon cannot find go, gofmt, rg, ... (compile, C-c s)
#   COLORTERM  or every terminal frame falls back to 256 colours
if [ "$NO_DAEMON" -eq 1 ]; then
  echo; say "skipping the daemon (--no-daemon). Use the 'e' alias."
else
  DAEMON_PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.cargo/bin"
  if [ "$OS" = "Darwin" ]; then
    DAEMON_PATH="$DAEMON_PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    echo
    if [ "$DRY" -eq 1 ]; then
      say "[dry-run] would write $PLIST and load it"
    else
      mkdir -p "$(dirname "$PLIST")"
      cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>              <string>gnu.emacs.daemon</string>
  <key>ProgramArguments</key>   <array>
    <string>$EMACS_BIN</string>
    <string>--fg-daemon</string>
  </array>
  <key>RunAtLoad</key>          <true/>
  <key>KeepAlive</key>          <true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>       <string>$DAEMON_PATH</string>
    <key>COLORTERM</key>  <string>truecolor</string>
  </dict>
  <key>StandardOutPath</key>    <string>/tmp/emacs-daemon.out</string>
  <key>StandardErrorPath</key>  <string>/tmp/emacs-daemon.err</string>
</dict>
</plist>
PLISTEOF
      say "wrote $PLIST"
      launchctl bootout "gui/$(id -u)/gnu.emacs.daemon" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null \
        && say "daemon loaded (launchctl)" \
        || say "could not load the daemon — run: launchctl bootstrap gui/$(id -u) $PLIST"
    fi
  else
    DAEMON_PATH="$DAEMON_PATH:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
    echo
    if ! command -v systemctl >/dev/null 2>&1; then
      say "no systemd here — skipping the daemon. Use the 'e' alias,"
      say "or start it by hand: emacs --daemon"
    elif [ ! -f /usr/lib/systemd/user/emacs.service ] && [ ! -f /lib/systemd/user/emacs.service ]; then
      say "emacs.service is not shipped by your Emacs package — skipping."
      say "Use the 'e' alias, or write the unit by hand."
    else
      run mkdir -p "$UNIT_DIR"
      if [ "$DRY" -eq 1 ]; then
        say "[dry-run] would write $UNIT_DIR/dotfiles.conf and enable emacs.service"
      else
        cat > "$UNIT_DIR/dotfiles.conf" <<UNITEOF
# Written by dotfiles/install-emacs.sh. See the daemon section there.
[Service]
Environment=PATH=$DAEMON_PATH
Environment=COLORTERM=truecolor
UNITEOF
        say "wrote $UNIT_DIR/dotfiles.conf"
        systemctl --user daemon-reload
        systemctl --user enable --now emacs.service \
          && say "daemon enabled and started (systemd)" \
          || say "could not start the daemon — check: systemctl --user status emacs.service"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------- done
echo
say "done"
echo
say "Open a new shell (or: exec zsh), then:"
say "  ec some-file.go     open it on the daemon"
say "  ec ~/.config/emacs/CHEATSHEET.md    the keybindings"
say "  ec ~/.config/emacs/COMPILE.md       the compile workflow"
echo
say "The first start installs the packages from MELPA — give it a few seconds."
echo
