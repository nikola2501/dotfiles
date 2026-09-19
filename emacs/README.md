# Emacs config — Tsoding škola

Bez LSP-a, bez tree-sitter-a. Sve eksplicitno, ništa magično.
Jezici: C (`simpc-mode`) i Go (`go-mode`).

## Struktura

```
init.el              glavni fajl, učitava rc/ module
rc/rc.el             bootstrap za pakete (rc/require)
rc/misc-rc.el        sitne funkcije i bindinzi
rc/compile-rc.el     compile workflow + rg  ← srce configa
local/simpc-mode.el  Tsodingov minimalni C mod (127 linija)
custom.el            Custom-generisano, ne diraj ručno
elpa/                instalirani paketi
```

## Paketi (9)

| Paket | Za šta |
|---|---|
| `naysayer-theme` | tema (paleta iz editora Jonathana Blowa) |
| `smex` | `M-x` sortiran po korišćenju |
| `ido-completing-read+` | completion za fajlove i bafere |
| `company` | autocomplete iz teksta bafera (ne semantički) |
| `magit` | git |
| `multiple-cursors` | višestruki kursori |
| `move-text` | pomeranje linija `M-n`/`M-p` |
| `go-mode` | Go highlighting + gofmt na snimanju |

Instalacija je ručna, preko `rc/require` — vidi `rc/rc.el`. Nema `use-package`,
nema lazy loadinga. Startup ~0.25s (prethodni config je bio 0.10s; ovo je
cena eager učitavanja i Tsoding je svesno plaća).

## Tema

`naysayer` — pozadina `#062329`, tekst `#d1b897`, komentari `#44b340`.
Emacs u terminalu emituje pravi 24-bitni RGB, pa izgleda isto kao u GUI-ju
(terminal mora podržavati truecolor — kitty/alacritty/foot/wezterm da).

**Važno za daemon:** bez `COLORTERM=truecolor` u okruženju *daemona* frame
dobija samo 256 boja i Emacs aproksimira boje teme — `#062329` postane
navy `#00005f`. Zato je ta promenljiva u
`~/.config/systemd/user/emacs.service.d/path.conf`. Postavljanje `COLORTERM`
u shell-u ne pomaže: `emacsclient` je ne prosleđuje daemonu.

Promena teme: izmeni `rc/require-theme` u `init.el` pa `emacs-restart`.
`gruber-darker` je i dalje instalirana ako hoćeš nazad.

## vc je isključen

`(setq vc-handled-backends nil)` u `rc/misc-rc.el`.

Emacs za svaki otvoreni fajl pokreće `git status --porcelain -z -- <fajl>`
samo da bi ispisao `Git:main` u modeline. Na velikom repou ta komanda sa
pathspec-om gubi git-ov untracked keš i lstat-uje celo stablo.

Izmereno na `repos/me/topolib` (19G, `.git` 2.3G, 8925 fajlova):

| | |
|---|---|
| `git status --porcelain -z -- 2048.go` | 1086 ms (7% CPU — čeka I/O) |
| `git status --porcelain -uall` (ceo repo) | 29 ms |
| otvaranje fajla **sa** vc | 1113 ms |
| otvaranje fajla **bez** vc | 7 ms |

Magit ne koristi vc i radi normalno (`C-c m s`). Gubiš samo `Git:main` u
modeline-u i `C-x v` komande.

## Dokumentacija

- `COMPILE.md` — compile workflow, glavna stvar za naučiti
- `CHEATSHEET.md` — prečice, Vim → Emacs

## Instalacija

```sh
./install-emacs.sh              # symlinkuje config + podesi daemon
./install-emacs.sh --no-daemon  # samo config
./install-emacs.sh --dry-run    # pokazi sta bi uradio
./install-emacs.sh --uninstall  # vrati sve kako je bilo
```

Radi na Linuxu (systemd) i macOS-u (launchd). Paketi se NE čuvaju u repou —
Emacs ih sam skine sa MELPA pri prvom pokretanju (`rc/rc.el`), pa prvi start
traje par sekundi i treba mu mreža.

Šta ostaje lokalno na mašini i ne ide u git: `elpa/`, `eln-cache/`, `var/`,
`custom.el`.

## Pokretanje

```sh
ec fajl.c        # emacsclient -t, na daemonu
e fajl.c         # emacs -nw, samostalno
emacs-restart    # posle izmene configa
```

`C-x C-c` zatvara samo tvoj frame, daemon ostaje.

### Daemon i okruženje

Daemon startuje systemd/launchd, ne tvoj shell — pa **ne vidi ništa što
exportuješ u `.zshrc`**. Dve stvari mu se moraju proslediti, i installer to
radi:

| | |
|---|---|
| `PATH` | inače ne nalazi `go`, `gofmt`, `rg` (compile, `C-c s`) |
| `COLORTERM=truecolor` | inače svaki tty frame pada na 256 boja |

Linux: `~/.config/systemd/user/emacs.service.d/dotfiles.conf`
macOS: `~/Library/LaunchAgents/gnu.emacs.daemon.plist`

Dodaš novi folder u `PATH` → dodaj ga u `install-emacs.sh` (promenljiva
`DAEMON_PATH`) pa pokreni installer ponovo.

### Zavisnosti

`git` (magit), `rg` (`C-c s`), `go` + `gofmt`, `make`/`gcc` (compile).
Installer proverava i javlja šta fali, ali ne instalira ništa.

Na macOS-u: `brew install emacs-plus --with-native-comp ripgrep coreutils`.

## Jezici

**C** — `simpc-mode` radi samo bojenje i indentaciju. Bez semantike, bez
zaglavljivanja na makroima. Greške dobijaš iz `C-c c`.

**Go** — `go-mode` + `gofmt` na snimanju (poziva spoljni program).
`compile-command` je podešen na `go build ./... && go vet ./...`.

## Šta nije preneto od Tsodinga

Njegovi jezici (porth, noq, basm, jai, umka, c3, fasm, tatr), njegovi
snippeti, org/agenda setup, autocommit, helm, paredit, ruski input.

## Prethodni configi

Ovaj config je zamenio Doom Emacs. Stari Doom config stoji u `emacs/doom/`
u ovom repou, nekorišćen — obriši ga slobodno ako ti ne treba.
