# Emacs config

No LSP, no tree-sitter. Everything explicit, nothing magic.
Languages: C (`simpc-mode`) and Go (`simpgo-mode`), both ours.
LSP exists but stays off — you switch it on by hand, per buffer (see below).

## Layout

```
init.el              the main file, loads the rc/ modules
rc/rc.el             package bootstrap (rc/require)
rc/misc-rc.el        small functions and bindings
rc/compile-rc.el     compile workflow + rg  <- the heart of the config
rc/nav-rc.el         project.el backend, winner, docs (C-c h)
rc/eglot-rc.el       LSP on demand, off by default (C-c l l)
local/simpc-mode.el  a minimal C mode (127 lines)
local/simpgo-mode.el the same idea for Go
custom.el            Custom-generated, do not edit by hand
elpa/                installed packages
```

## Packages (8)

| Package | What for |
|---|---|
| `naysayer-theme` | the theme |
| `vertico` | candidate list at the bottom, one per line |
| `orderless` | type fragments of a name in any order |
| `marginalia` | shows the shortcut and a description next to each command |
| `company` | completion from buffer text, not semantic |
| `magit` | git |
| `multiple-cursors` | multiple cursors |
| `move-text` | move lines with `M-n` / `M-p` |

Installation is manual, through `rc/require` — see `rc/rc.el`. No
`use-package`, no lazy loading. Startup is 0.20 s measured with
`emacs-init-time`; that is the price of eager loading, paid knowingly.

`elpa/` also holds `ido-completing-read+`, `smex`, `posframe` and `memoize`,
left over from the earlier completion setup and no longer loaded by anything.
`gruber-darker-theme` is kept on purpose. The rest are dependencies of magit.

## Theme

`naysayer` — background `#062329`, text `#d1b897`, comments `#44b340`.
Emacs in a terminal emits real 24-bit RGB, so it looks the same as in a GUI
frame (the terminal has to support truecolor — kitty, alacritty, foot and
wezterm do).

**Important for the daemon:** without `COLORTERM=truecolor` in the *daemon's*
environment a frame only gets 256 colors and Emacs approximates the theme —
`#062329` turns into navy `#00005f`. That is why the variable lives in
`~/.config/systemd/user/emacs.service.d/path.conf`. Setting `COLORTERM` in
the shell does not help: `emacsclient` does not forward it to the daemon.

Changing the theme: edit `rc/require-theme` in `init.el`, then `emacs-restart`.
`gruber-darker` is still installed if you want to go back.

## vc is switched off

`(setq vc-handled-backends nil)` in `rc/misc-rc.el`.

For every file it opens, Emacs runs `git status --porcelain -z -- <file>`
just to print `Git:main` in the mode line. On a large repository that command
with a pathspec loses git's untracked cache and lstats the whole tree.

Measured on `repos/me/topolib` (19G, `.git` 2.3G, 8925 files):

| | |
|---|---|
| `git status --porcelain -z -- 2048.go` | 1086 ms (7% CPU — waiting on I/O) |
| `git status --porcelain -uall` (whole repo) | 29 ms |
| opening a file **with** vc | 1113 ms |
| opening a file **without** vc | 7 ms |

Magit does not use vc and works normally (`C-c m s`). All you lose is
`Git:main` in the mode line and the `C-x v` commands.

Note that `project.el` finds projects through vc, so switching vc off breaks
the whole `C-x p` prefix. `rc/nav-rc.el` puts it back with its own backend.

## Documentation

- `COMPILE.md` — the compile workflow, the main thing to learn
- `CHEATSHEET.md` — shortcuts, Vim to Emacs

Both open from inside any project: `C-c h k` and `C-c h c`.

## Installation

```sh
./install-emacs.sh              # symlink the config and set up the daemon
./install-emacs.sh --no-daemon  # config only
./install-emacs.sh --dry-run    # show what it would do
./install-emacs.sh --uninstall  # put everything back
```

Works on Linux (systemd) and macOS (launchd). Packages are NOT kept in the
repository — Emacs downloads them from MELPA on the first run (`rc/rc.el`),
so the first start takes a few seconds and needs a network.

What stays on the machine and out of git: `elpa/`, `eln-cache/`, `var/`,
`custom.el`.

## Running it

```sh
ec file.c        # emacsclient -t, against the daemon
e file.c         # emacs -nw, standalone
emacs-restart    # after changing the config
```

`C-x C-c` closes your frame only; the daemon keeps running. This is worth
remembering: config changes do not appear until the daemon itself restarts.
`M-x emacs-uptime` tells you how long the process has been up, and the frame
name in the mode line (`F1`, `F2`, ...) counts frames within one process.

### The daemon and its environment

The daemon is started by systemd or launchd, not by your shell, so it **sees
nothing you export in `.zshrc`**. Two things have to be handed to it, and the
installer does that:

| | |
|---|---|
| `PATH` | otherwise it cannot find `go`, `gofmt`, `rg` (compile, `C-c s`) |
| `COLORTERM=truecolor` | otherwise every tty frame drops to 256 colors |

Linux: `~/.config/systemd/user/emacs.service.d/dotfiles.conf`
macOS: `~/Library/LaunchAgents/gnu.emacs.daemon.plist`

Adding a directory to `PATH` means adding it to `install-emacs.sh` (the
`DAEMON_PATH` variable) and running the installer again.

### Dependencies

`git` (magit), `rg` (`C-c s`), `go` + `gofmt`, `make` / `gcc` (compile).
The installer checks and reports what is missing; it installs nothing.

On macOS: `brew install emacs-plus --with-native-comp ripgrep coreutils`.

## Languages

**C** — `simpc-mode` only does highlighting and indentation. No semantics, no
hanging on macros. Errors come from `C-c c`.

**Go** — `simpgo-mode`, built on the same idea. Highlights keywords, comments
and literals; function and variable names stay uncoloured. `gofmt` on save
calls the external program directly (if the code does not parse, the buffer
is left alone). `compile-command` is `go build ./... && go vet ./...`.

Measured on a 6000-line Go file:

| | whole file | visible screen |
|---|---|---|
| `go-mode` (package, 3122 lines) | 562.8 ms | 2.49 ms |
| `simpgo-mode` (190 lines) | 10.7 ms | **0.11 ms** |

The same comparison for C: `simpc` 0.07 ms, `c-ts-mode` (tree-sitter) 60.5 ms
over the whole file, `cc-mode` 5.75 ms per screen.

## LSP — on demand, not by default

For other people's code. Own projects keep the regexp and grep workflow.

`rc/eglot-rc.el`. Not a package — `eglot` ships with Emacs 30 and is
**autoloaded**, so until you call it, it is not in memory at all.

```
C-c l l    turn it on in this buffer   (gopls for Go, clangd for C)
C-c l q    turn it off, the server dies with it
C-c l r    rename the symbol everywhere
C-c l a    code actions / quick fix
```

While it runs the mode line shows `[eglot:gopls]` and you get:

| | |
|---|---|
| `M-.` | jump to the definition, precisely (`C-c d`, the regexp one, stays) |
| `M-,` | jump back |
| `M-?` | every reference |
| `C-h .` | documentation for the symbol under point |
| `M-g n` / `M-g p` | walk the diagnostics, the same keys as for errors |

Completion turns semantic on its own — `company-capf` is already the first
backend.

### What it costs

Nothing until you switch it on. Measured:

| | |
|---|---|
| `load rc/eglot-rc.el` | 0.12 ms |
| startup with / without the file | 162 / 163 ms (inside the noise) |
| `post-command-hook` | unchanged, only `eldoc-schedule-timer` |
| `featurep 'eglot` after startup | `nil` |
| the first `require`, on `C-c l l` | 21 ms, paid only then |

The whole file is one `with-eval-after-load` plus four bindings.

### Details

`simpgo-mode` and `simpc-mode` are ours and eglot does not know them, so
`gopls` and `clangd` are mapped onto them by hand in `eglot-server-programs`.

eglot finds the project root through `project.el`, which means through the
backend in `rc/nav-rc.el` — the same root `C-c c` builds from.

Two settings apply only while a server runs: `eglot-events-buffer-config` at
size 0 (the default logs every JSON message into a 2 MB buffer) and
`eglot-autoshutdown t` (without it `gopls` lingers in the background once you
close the project's buffers).

`clangd` wants a `compile_commands.json` at the root; `gopls` only needs
`go.mod`.

To remove it: delete `rc/eglot-rc.el` and its `load` line from `init.el`.
