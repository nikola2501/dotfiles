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
./install-sublime.sh --force --prune  # link first, then prune (see below)
./install-sublime.sh --uninstall
```

Config is symlinked from `sublime/User/` into Sublime's User folder, which the
script locates per OS (`~/.config/sublime-text` on Linux,
`~/Library/Application Support/Sublime Text` on macOS). Nested files such as
`mytheme/` are linked individually, so the directory itself is never replaced.

**Packages** are not installed by the script. Package Control reads
`installed_packages` from `User/Package Control.sublime-settings` and installs
whatever is missing on the next launch. The list is deliberately small:

`Debugger` · `Git blame` · `GitSavvy` · `Harpoon` · `LSP` (+ `clangd`, `gopls`,
`rust-analyzer`) · `MarkdownPreview` · `Odin` · `Package Control` · `Terraform`

No CTags either — LSP does the same job from a real index rather than a tags
file, and its `.tags` entries have been taken out of the exclude patterns.

No Terminus: nothing imports it unconditionally, and the only things it carried
were the Run/Debug code lens in Rust, the run-test lens in Go, and Debugger's
external terminal. `User/Debugger.sublime-settings` sets `external_terminal` to
`platform` so Debugger stops asking for it.

No colour-scheme packages: the active scheme is
`User/mytheme/Cyanide - Matrix.tmTheme`, a local file, so it survives on any
machine. The UI theme is `Cyanide - Matrix.sublime-theme`, which comes from the
hand-installed `Theme - Cyanide` — see the next section.

### Keys

Every shortcut this repo adds, plus the Sublime defaults that are easy to
forget. The table below is **generated** — `bin/dot-keys` reads the `//`
comments and section headers out of `sublime/User/Default.sublime-keymap`, so
documenting a new binding means writing the comment next to it and nothing
else. Same idea as `hx-keys` on the Helix side.

Three ways to reach it without leaving the editor: `F1` regenerates and opens
`KEYS.md`, `shift+F1` searches every binding by key *or* description and runs
the one you pick, and `dot-keys | fzf` works from a shell.

<!-- >>> dotfiles: keys >>> -->

Generated by `bin/dot-keys` from the comments in
`sublime/User/Default.sublime-keymap`. Do not edit between the markers.
`KEYS.md` has the same table plus the command names and GitSavvy's
view-local keys; `shift+F1` searches all of it and runs what you pick.

**LSP**

| key | does |
| --- | --- |
| `f8` | Hover dokumentacija za simbol pod kursorom |
| `f12` | LSP: Goto Definition |
| `shift+f12` | LSP: Find References |

**Build systems**

| key | does |
| --- | --- |
| `shift+f8` | Build system: UniversalGit |
| `shift+f9` | Build system: Tenet |

**GitSavvy**

| key | does |
| --- | --- |
| `ctrl+shift+s` | The equivalent of `git status`. |
| `ctrl+shift+,` | PR: inline diff current file |

**Pane navigation**

| key | does |
| --- | --- |
| `alt+1` | Fokus na levi panel |
| `alt+2` | Fokus na desni panel |

**Harpoon**

| key | does |
| --- | --- |
| `ctrl+alt+a` | Harpoon: Add file |
| `ctrl+alt+e` | Harpoon: Edit list |
| `ctrl+alt+l` | Harpoon: Show list |
| `ctrl+alt+c` | Harpoon: Clear list |
| `ctrl+alt+n` | Harpoon: Next file |
| `ctrl+alt+b` | Harpoon: Previous file |
| `ctrl+alt+1..9` | Harpoon: skok na slot N |

**PR REVIEW (pr_review.py)**

| key | does |
| --- | --- |
| `ctrl+shift+d` | PR: diff vs base branch (all files) |
| `ctrl+shift+v` | PR: diff current file vs base branch |
| `ctrl+shift+b` | PR: diff vs branch... |
| `ctrl+shift+c` | PR: commits in this PR |

**Pomeranje tabova (tab_tools.py)**

| key | does |
| --- | --- |
| `super+shift+1..9` | Prebaci tab na mesto N |

**Cheatsheet (keys_help.py)**

| key | does |
| --- | --- |
| `f1` | Keys: open cheatsheet (KEYS.md) |
| `shift+f1` | Keys: search bindings |

**Paritet sa nvim configom**

| key | does |
| --- | --- |
| `f9` | Sledeca diagnostika (nvim ]d) |
| `f10` | Prethodna diagnostika (nvim [d) |
| `ctrl+shift+e` | Lista diagnostike (nvim <leader>dd) |
| `ctrl+f12` | LSP implementations (nvim gi) |
| `ctrl+shift+g` | Repo u Sublime Merge-u (nvim <C-g> lazygit) |
| `ctrl+shift+l` | Permalink na liniju u clipboard (nvim <leader>gl) |
| `ctrl+shift+alt+l` | Otvori fajl na GitHubu (nvim <leader>gc) |
| `ctrl+shift+a` | Blame trenutnog fajla (nvim <leader>A) |
| `ctrl+shift+h` | Commiti koji su dirali ovaj fajl (nvim <leader>c) |
| `ctrl+f9` | Skoci na diagnostiku iz liste u fajlu |
| `ctrl+alt+v` | Commit ciji SHA stoji na ovoj liniji (nvim <leader>v Gshow) |

**Surround (surround.py)**

| key | does |
| --- | --- |
| `ctrl+shift+y` | Opkoli selekciju ili rec (nvim <leader>y) |
| `ctrl+shift+x` | Obrisi okruzujuci par (nvim <leader>x) |
| `ctrl+shift+u` | Promeni par u drugi (nvim <leader>C) |

**Sirenje selekcije (text objekti)**

| key | does |
| --- | --- |
| `ctrl+shift+i` | Selektuj blok na ovom nivou uvlacenja (telo funkcije, strukture) |
| `ctrl+shift+o` | Selektuj paragraf / blok do praznih linija |

### Keys Sublime already had

Not ours, not in the keymap — just easy to forget.

**Expanding a selection (text objects)**

| key | does |
| --- | --- |
| `cmd+shift+space` | expand to scope; repeat to step OUT (vim `vi"`, helix `mi"`) |
| `ctrl+shift+m` | expand to brackets; repeat to walk out through nesting |
| `cmd+shift+a` | expand to smart / HTML tag |
| `cmd+l` | expand to line (`cmd+alt+l` the line before) |
| `cmd+d` | expand to word, then to the next occurrence |
| `cmd+u` | **step back IN** — soft_undo walks the selection history |

**Git, without a package**

| key | does |
| --- | --- |
| `ctrl+. / ctrl+,` | next / previous modification (vim `]c` / `[c`) |
| `cmd+k then cmd+shift+z` | revert the modification under the caret |

**Navigation**

| key | does |
| --- | --- |
| `cmd+p` | Goto Anything: files |
| `cmd+r` | symbols in this file (`cmd+shift+r` across the project) |
| `cmd+shift+f` | find in files |
| `f4 / shift+f4` | next / previous build error |

<!-- <<< dotfiles: keys <<< -->

### Hand-installed packages and `--prune`

`--prune` moves anything not on the list into
`Installed Packages/.removed-<timestamp>/` rather than deleting it. Two things
make that safe to run:

**`sublime/prune-keep.txt`** names packages installed by hand rather than by
Package Control — currently `HCL.tmLanguage`, `protobuf-syntax-highlighting`
and `Theme - Cyanide`. They cannot go in `installed_packages`: Package Control
does not know them, cannot install them, and deletes them as orphans. Without
this file a single `--prune` removes them and nothing ever brings them back.

**The link check.** Sublime reads the `User/` copy of
`Package Control.sublime-settings`; `--prune` reads the repo's. If they are not
the same file the two disagree — prune moves a package away, Package Control
sees it missing from *its* list and downloads it again, and every run drops
another `.removed-*` directory. So `--prune` refuses unless that file is a
symlink into the repo. Link it and prune in one go with
`--force --prune`.

### Settings and keymaps

| file | scope |
|---|---|
| `Preferences.sublime-settings` | everything shared |
| `Preferences (Linux/OSX).sublime-settings` | display only — `ui_scale`, nothing else |
| `Default.sublime-keymap` | **all platforms** — one file, same keys everywhere |

There are deliberately no `Default (Linux)` / `Default (OSX)` keymaps. One file
means one place to change a shortcut, and the same key on every machine.

**`font_size` stays in the shared file, never in a platform one.** Sublime's
"Font: Larger" (`Cmd+=` / `Ctrl+=`) writes `font_size` into
`Preferences.sublime-settings`, and a `font_size` in
`Preferences (OSX).sublime-settings` layers over it — so the keystroke appears to
do nothing. Displays differ in pixel density, not in preferred point size, so
`ui_scale` is the per-machine knob: 1.5 on macOS here, 1.2 on Linux.

### Making the UI bigger

The editor font and the UI are separate. Three levers, coarsest first:

| lever | scope |
|---|---|
| `ui_scale` | the whole UI — text, icons, padding, scrollbars |
| theme options (`large_ui_font`, `tabs_large`, `large_scroll_bars`) | what the theme chooses to expose |
| `font.size` rules in `mytheme/Cyanide - Matrix.sublime-theme` | any class, any size |

`ui_scale` first: it scales padding along with the text, so the sidebar does not
end up cramped around larger glyphs. `large_ui_font` is fixed at 14px and only
reaches `sidebar_label`, `label_control` and `tab_label` — go to explicit
`font.size` rules for anything else. That theme file already overrides the
same-named one in the hand-installed `Theme - Cyanide` package, because Sublime
merges themes by filename with `User/` winning.

`ui_scale` needs a restart. Theme options apply as soon as you save.

| key | does |
|---|---|
| `f8` | hover |
| `f12` | go to definition (LSP's, replacing the built-in) |
| `shift+f12` | find references (LSP's, replacing the built-in) |
| `shift+f8` | switch build system to UniversalGit |
| `shift+f9` | switch build system to Tenet |
| `ctrl+shift+s` | GitSavvy: status (the `git status` equivalent) |
| `ctrl+shift+,` | GitSavvy: inline diff — `[a]`/`[b]` toggles before/after, `[n]`/`[p]` walks the file history |
| `alt+1` / `alt+2` | focus pane 1 / 2 — **carried over, see the caveat below** |
| `ctrl+alt+a` | harpoon: mark this file (again to unmark) |
| `ctrl+alt+1..9` | harpoon: jump to slot N |
| `ctrl+alt+e` | harpoon: edit the mark list as a buffer |
| `ctrl+alt+l` | harpoon: pick from a quick panel |
| `ctrl+alt+n` / `ctrl+alt+b` | harpoon: next / previous mark |
| `ctrl+alt+c` | harpoon: clear |

The harpoon letters match the Helix side (`<space>za/ze/zl/zc`, `A-1..A-9`) so
the muscle memory carries over. `ctrl+alt` is the one modifier pair that is free
on both platforms and safe on macOS — with `ctrl` held, Option stops producing
characters.

**Function keys are the only portable choice.** The modifiers are not:

- `ctrl` is primary on Linux, but macOS reserves many `ctrl` combos itself
- `super` is Command on macOS, and on Linux the window manager usually eats it
- `alt` is fine on Linux; on macOS it is Option and **types characters** —
  `alt+d` is `∂`, `alt+1` is `¡` — so `alt` bindings there insert junk

**On a new Mac, turn on "Use F1, F2, etc. keys as standard function keys"**
(System Settings → Keyboard), or the F-keys send brightness and volume instead.
Holding Fn works too. This is the one macOS setup step.

Keys left alone because Sublime's own defaults are worth keeping: `f4` /
`shift+f4` step through build results (the quickfix keys), `f7` builds, `f3`
finds next, `f11` is full screen on Linux. And do not re-bind these either:

| keys | does | default on |
|---|---|---|
| `ctrl+1..9` | focus pane | both |
| `alt+1..9` | select tab | Linux |
| `super+1..9` | select tab | macOS |

**The `alt+1` / `alt+2` caveat.** Those two bindings came over from the old
`Default (OSX).sublime-keymap` and they break both rules in the table above:
`ctrl+1..9` already focuses panes on both platforms, so they are redundant, and
on Linux they take `alt+1..9` away from tab selection. On macOS bare `alt` is
Option, so they type `¡` and `™` instead of switching panes. Kept on purpose —
delete the two lines from `Default.sublime-keymap` to get the defaults back.

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
