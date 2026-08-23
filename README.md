# dotfiles

Config for Linux and macOS. One command sets a machine up.

```sh
git clone https://github.com/nikola2501/dotfiles.git ~/repos/me/dotfiles
~/repos/me/dotfiles/install.sh
```

Add `--helix` to also clone and build the Helix fork and enable `hxp`.
Add `--dry-run` first if you want to see what it would touch.

Everything is **symlinked, never copied** — editing `~/.zshrc` edits this repo,
so the two cannot drift apart. Any real file already in the way is moved to
`<name>.bak-<timestamp>` first; nothing is overwritten. `--uninstall` removes the
symlinks and restores the newest backup.

## Layout

| path | goes to |
|---|---|
| `helix/config.toml` | `~/.config/helix/config.toml` |
| `helix/languages.toml` | `~/.config/helix/languages.toml` |
| `zsh/zshrc.Linux` / `zsh/zshrc.Darwin` | `~/.zshrc`, picked by `uname -s` |
| `zsh/common.zsh` | sourced by both — PATH and the `hxp` alias |
| `bin/hx-make`, `bin/hx-harpoon` | `~/.local/bin/` |

The two shells are genuinely different machines — macOS has oh-my-zsh,
`/Applications` paths and `/Users/nikola`; Linux does not — so each OS gets its
own `.zshrc` and only the shared parts live in `zsh/common.zsh`. Put anything
that should apply everywhere in `common.zsh`, not in one of the two.

`install.sh` only manages what is listed above. The other directories
(`tmux/`, `ghostty/`, `i3/`, `alacritty/`, `sway/`, `zellij/`, `emacs/`, `zed/`,
`nixos/`, `claude/`, `starship.toml`, `.vimrc`) are still just stored here —
link them by hand, or extend `install.sh` when you want them automated.

## Helix: quickfix and harpoon

`bin/hx-make` and `bin/hx-harpoon` add Vim's quickfix / Emacs' compile-mode and
neovim's harpoon to **stock Helix** — no plugin system, no Steel fork.

### Quickfix

| key | does |
|---|---|
| `<space>m` | build, jump to the top of the quickfix buffer |
| `<space>M` | build, keep the cursor where it is |
| `<space>q` | refresh / reopen the quickfix buffer |
| `A-ret` | open the `path:row:col` on the current line, cursor on that exact spot |

Builds run **in the background** — Helix stays responsive. A tmux or desktop
notification fires when one finishes; press `<space>q` to see the result.

`A-ret` works in **any saved buffer**, not just quickfix: a log, `git grep`
output, a stack trace you pasted in.

### Harpoon

| key | does |
|---|---|
| `<space>za` | pin the current file + line |
| `A-1` … `A-9` | jump to pin N |
| `<space>ze` | open the pin list as a buffer |
| `<space>zl` | list pins in the statusline |
| `<space>zc` | clear |

Pins are per-project and persist. Re-pinning a file updates its line but keeps
its slot, so `A-2` stays `A-2`. The pin list is a plain buffer — `dd` to delete,
move lines to reorder, `A-ret` to jump. No special UI.

`A-1` rather than `C-1` because terminals cannot encode Ctrl+digit reliably
through tmux. Helix also has no "go to buffer N" command at all — only
`buffer-next`/`buffer-previous` — and buffer indices shift as you open and close
files, whereas pinned slots are stable.

### Build commands

`hx-make` walks up to the project root and picks a command:

| found | runs |
|---|---|
| `.hx-make` | whatever is in the file |
| `Cargo.toml` | `cargo build --message-format=short` |
| `go.mod` | `go build ./...` |
| `build.zig` | `zig build` |
| `CMakeLists.txt` + `build/` | `cmake --build build` |
| `Makefile` | `make` |
| `package.json` | `npm run build` |
| `*.odin` or `ols.json` | `odin build . -debug` |
| `*.c` | `cc -fsyntax-only -Wall -Wextra *.c` |

Override per project with a `.hx-make` in the root:

```sh
echo 'odin build src -out:bin/game -debug' > .hx-make
```

One-off anything, then `<space>q`:

```
:sh hx-make golangci-lint run
:sh hx-make rg --vimgrep TODO
```

Output is normalized to absolute `path:row:col:`, which covers Odin's
`file(row:col)`, MSVC's `file(row,col)`, ripgrep's `--vimgrep`, and the
gcc/clang/go/zig/cargo family as-is.

### How it works

Three vanilla-Helix facts:

1. **`:open path:row:col` already jumps to a position** — `parse_file` in
   `helix-term/src/args.rs`. `gf` / `goto_file` does *not* parse `:row:col`, it
   only opens the path. That is why everything goes through `:open`.
2. **`%sh{...}` recursively expands `%{...}` inside itself before running the
   shell** — `expand_shell` in `helix-view/src/expansion.rs`. So a keybinding can
   hand editor state to a shell command and feed the result back into a typed
   command.
3. **Keybindings can be arrays** mixing static and `:` typed commands, through
   the same expansion path.

The jump binding reads the current line straight off disk, greps a location out
of it, and hands it to `:open`:

```toml
"A-ret" = ":open %sh{sed -n \"%{cursor_line}p\" \"%{file_path_absolute}\" | grep -oE '...' | head -1}"
```

Two traps if you extend this:

- Use `%{file_path_absolute}`, **never** `%{buffer_name}`, when passing a path to
  the shell. `buffer_name` yields a literal `~` that stays unexpanded inside
  quotes and silently breaks for every file under `$HOME`.
- Avoid `{` `}` inside `%sh{...}` — the tokenizer scans for the closing brace.
  Use `$( )` rather than `${ }`.

**Limit:** Helix has no timer or event hook without a plugin system, so nothing
can auto-refresh the quickfix buffer when a background build finishes. You press
`<space>q`. That is the one thing a real plugin system would buy here.

## The Helix fork

[`nikola2501/helix-plugin`](https://github.com/nikola2501/helix-plugin) is a
plain mirror of upstream Helix — despite the name it has **no** plugin system.
Nothing from this kit lives in it, so it always fast-forwards:

```sh
cd ~/repos/me/helix-plugin
git fetch upstream && git merge --ff-only upstream/master
cargo build --profile opt
./target/opt/hx --grammar fetch && ./target/opt/hx --grammar build   # only if runtime/ or languages.toml changed
```
