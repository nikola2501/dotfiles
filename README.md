# dotfiles

Config for Linux and macOS. Two installers, one per editor:

| script | sets up |
|---|---|
| `install-helix.sh` | Helix config, themes, the `hx-*` scripts, the `h` alias |
| `install-sublime.sh` | Sublime Text's `User/` config and package list |

Both symlink rather than copy, back up anything in the way, and ask before
replacing a file that differs from the repo's copy.

```sh
git clone https://github.com/nikola2501/dotfiles.git ~/repos/me/dotfiles
~/repos/me/dotfiles/install-helix.sh
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

## Layout

| path | goes to |
|---|---|
| `helix/config.toml` | `~/.config/helix/config.toml` |
| `helix/languages.toml` | `~/.config/helix/languages.toml` |
| `helix/themes/*.toml` | `~/.config/helix/themes/` |
| `bin/hx-*` (`make`, `harpoon`, `git`, `diff`, `jump`, `keys`) | `~/.local/bin/` |
| `sublime/User/**` | Sublime's `Packages/User/` (via `install-sublime.sh`) |
| the `# >>> dotfiles: helix >>>` block | appended to `~/.zshrc` |

`install-helix.sh` only manages what is listed above. The other directories
(`tmux/`, `ghostty/`, `i3/`, `alacritty/`, `sway/`, `zellij/`, `emacs/`, `zed/`,
`nixos/`, `claude/`, `.zshrc`, `starship.toml`, `.vimrc`) are stored
here but not linked — link them by hand, or extend `install-helix.sh` when you want
them automated.

## Themes

A theme lives in the Helix **runtime**, which is per-installation, while this
config is shared. So a machine with an older Helix silently falls back to the
default — there is no error message, the colours are just wrong.

Any theme this config names therefore travels with it, in `helix/themes/`.
Helix searches `$config/themes` before the runtime dirs (`application.rs` puts
`config_dir()` at the front of the theme parent dirs), so a file there wins no
matter which Helix build is installed.

`atlas-ragnarok` is a **stock upstream theme**, added in upstream commit
`0ca8da6c5` (2026-07-20) — nothing fork-specific about it. It is vendored here
so it works on a machine whose Helix predates that commit.

To add another theme, drop it in `helix/themes/` and re-run `install-helix.sh`.

## Remembering the keys

`<space>i` opens a cheatsheet in a buffer.

It exists because **Helix cannot label a custom keybinding.** A bound typed
command shows in the SPACE menu as its raw text — `commands.rs` builds the doc as
`format!(":{} {:?}", name, args)` whenever there are arguments — a command
sequence shows `[Multiple commands]`, and a submenu's name is `#[serde(skip)]`,
so `v` and `z` show nothing at all. Only built-in commands carry a description.

Fixing that properly means patching `helix-term/src/keymap.rs`, which would cost
the fork its `git merge --ff-only` sync. Not worth it for a label, so the
cheatsheet lives in a buffer instead.

`hx-keys` generates it from the **comments in `helix/config.toml`** — the same
lines that document each binding in place, so there is nothing to keep in sync.
Add a `# <space>x : does the thing` comment next to a new binding and it appears.

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

### Git changes

| key | shows |
|---|---|
| `<space>vs` | which **files** changed — "what am I working on" |
| `<space>vc` | which **lines** changed vs HEAD, staged and unstaged both |
| `<space>vb` | which **lines** changed vs the merge-base with main/master |

`A-ret` jumps from these exactly as it does from the quickfix buffer — same key,
same list, no separate diff mode to learn.

Two granularities because they answer different questions: files for "what am I
touching", lines for "what did I actually do".

`<space>vb` diffs against the **merge-base**, not against main itself. That is
the whole trick — you see your branch's changes, not everything that landed on
main since you branched. It does not use `...HEAD` either, so uncommitted work
counts: before you push, "different from main" includes what you have not
committed yet. Override the base with `:sh hx-git branch some-ref`.

The mechanism is `git diff -U0`. With zero context lines every hunk header is
exactly one change and the `+N` in it **is** the line to jump to, so nothing has
to work out a position inside a diff — the output is plain `path:row: text`,
which is why the existing jump binding needed no changes at all. Each entry
shows the `+` line (what is in the file you are about to land in), falling back
to the `-` line for a pure deletion, falling back to git's `xfuncname` context.

Deleted files show up under `<space>vs` but not in the line lists — there is no
line left to jump to.

### Reviewing a change

Helix has **no diff mode** — there is no `:diffthis`, no vimdiff equivalent. But
it does ship a tree-sitter `diff` grammar with `@diff.plus` / `@diff.minus`
highlights for `.diff`, `.patch` and `.rej`, so a diff written to a `.diff` file
and opened in a buffer is properly coloured through your theme.

| key | shows |
|---|---|
| `<space>vd` | the diff vs HEAD |
| `<space>vr` | the diff vs the merge-base — **this is the PR review one** |
| `<space>vp` | the same review diff in a tmux popup through `delta` |

`A-ret` works from **anywhere inside the diff** — a `+` line, a context line, a
`-` line, or the `@@` header. It resolves the position back to the real file and
line, so you land in the actual buffer with LSP and the whole repo around you.
A `-` line lands where the deleted line used to be.

Reviewing a PR locally:

```sh
gh pr checkout 123
```

then `<space>vr` in Helix. Everything is your working tree, so goto-definition,
references and diagnostics all work while you read.

Context lines default to 5 (git's default 3 is thin for reading); override with
`HX_DIFF_CONTEXT`.

#### On delta

`delta` renders ANSI colour, and a Helix buffer displays text, not ANSI — piping
delta into a buffer shows literal `ESC[38;2;...` escapes. So delta cannot be the
in-editor viewer. It is excellent in a terminal, which is what `<space>vp` is
for: `hx-diff --raw review | delta` inside a tmux popup. Read there, jump here.

### Lists vs the diff

Both exist because they answer different questions:

- `<space>vs` / `<space>vc` / `<space>vb` — **lists**. Compact, one line per
  change, fast to walk with `n`/`N` and jump from. "What did I touch."
- `<space>vd` / `<space>vr` — **the diff itself**. Surrounding context, what the
  code looked like before. "Is this change right."

`A-ret` is the same key in both. `hx-jump` looks at the buffer and decides:
a unified diff gets the position resolved inside it, anything else gets the
first `path:row[:col]` pulled off the line.

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

## Sublime Text

```sh
./install-sublime.sh              # link the User/ config
./install-sublime.sh --dry-run    # see what it would touch first
./install-sublime.sh --prune      # also remove packages not in the list
./install-sublime.sh --uninstall
```

Config is symlinked from `sublime/User/` into Sublime's User folder, which the
script locates per OS (`~/.config/sublime-text` on Linux,
`~/Library/Application Support/Sublime Text` on macOS). Nested files such as
`mytheme/` are linked individually, so the directory itself is never replaced.

**Packages** are not installed by the script. Package Control reads
`installed_packages` from `User/Package Control.sublime-settings` and installs
whatever is missing on the next launch. The list is deliberately small:

`Debugger` · `Git blame` · `GitSavvy` · `LSP` (+ `clangd`, `gopls`,
`rust-analyzer`) · `Odin` · `Package Control`

No CTags either — LSP does the same job from a real index rather than a tags
file, and its `.tags` entries have been taken out of the exclude patterns.

No Terminus: nothing imports it unconditionally, and the only things it carried
were the Run/Debug code lens in Rust, the run-test lens in Go, and Debugger's
external terminal. `User/Debugger.sublime-settings` sets `external_terminal` to
`platform` so Debugger stops asking for it.

No theme or colour-scheme packages: the active scheme is
`User/mytheme/Cyanide - Matrix.tmTheme`, a local file, and the UI theme is
Sublime's built-in Default Dark. `--prune` moves anything not on the list into
`Installed Packages/.removed-<timestamp>/` rather than deleting it.

### Settings and keymaps per OS

Sublime supports platform-specific files natively, so this uses them rather than
inventing anything:

| file | scope |
|---|---|
| `Preferences.sublime-settings` | everything shared |
| `Preferences (Linux/OSX).sublime-settings` | display only — font size, UI scale |
| `Default (Linux).sublime-keymap` | Linux bindings |
| `Default (OSX).sublime-keymap` | macOS bindings |

**macOS modifiers**, which is where keymaps used to go wrong:

- `super` is Command — the primary modifier, as `ctrl` is on Linux
- `ctrl` is Control, mostly reserved by macOS itself
- `alt` is Option and **types characters** — `alt+1` is `¡`, `alt+d` is `∂`. An
  `alt+letter` or `alt+digit` binding either does nothing or inserts junk. Never
  bind `alt` alone on macOS; only `super+alt`.

That is why hover is `f12` on macOS but `alt+d` on Linux.

Do not re-bind what Sublime already gives you — that was the other source of
confusion:

| keys | does | default on |
|---|---|---|
| `ctrl+1..9` | focus pane | both |
| `alt+1..9` | select tab | Linux |
| `super+1..9` | select tab | macOS |

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
