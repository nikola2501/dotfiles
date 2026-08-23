# dotfiles

Config for Linux and macOS. One command sets a machine up.

```sh
git clone https://github.com/nikola2501/dotfiles.git ~/repos/me/dotfiles
~/repos/me/dotfiles/install.sh
```

| flag | |
|---|---|
| `--dry-run` | show what would happen, change nothing. Run this first. |
| `--helix` | also clone and build the Helix fork, enabling `h` |
| `--force` | replace differing files without asking |
| `--uninstall` | remove the symlinks and restore the newest backups |

Needs `git`. `--helix` also needs `cargo`. The scripts need `awk`, `sed`, `grep`.

**`--helix` is not quick:** the Rust build takes a few minutes, and fetching and
building the ~300 tree-sitter grammars takes longer and lands about **2.4 GB** in
`runtime/grammars`. Don't start it on a tethered connection.

## What it does to your files

**Your `~/.zshrc` is never replaced, never symlinked, never moved aside.** The
installer appends one marked block to it and, on re-runs, rewrites only that
block:

```zsh
# >>> dotfiles: helix >>>
export PATH="$HOME/.local/bin:$PATH"          # hx-make, hx-harpoon
HELIX_FORK="${HELIX_FORK:-$HOME/repos/me/helix-plugin}"
if [ -x "$HELIX_FORK/target/opt/hx" ]; then
  alias h="HELIX_RUNTIME=$HELIX_FORK/runtime $HELIX_FORK/target/opt/hx"
fi
# <<< dotfiles: helix <<<
```

That is the whole footprint in your shell: `~/.local/bin` on PATH, and `h` for
the fork. `--uninstall` strips the block back out.

The helix config and the `bin/` scripts *are* symlinked, since those files are
this repo's to own. There the rules are:

1. Already the right symlink -> nothing happens (`ok`).
2. A real file **identical** to the repo's -> replaced, nothing to lose.
3. A real file that **differs** -> says so with a line count and **asks**. Not a
   terminal? It skips and tells you how to compare. `--force` skips the question.
4. Anything replaced is moved to `<name>.bak-<timestamp>` first. Nothing is ever
   deleted.

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
