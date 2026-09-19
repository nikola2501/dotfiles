# Emacs za Vim korisnika

Emacs **nije modalan**. Kucaš i tekst ulazi. `C-x` = Ctrl+x, `M-x` = Alt+x.

## Tri stvari za prvi dan

| `C-g` | **PANIK DUGME** — prekida sve. Tvoj `Esc`. |
|---|---|
| `C-x C-s` | sačuvaj |
| `C-x C-c` | izađi (zatvara frame, daemon ostaje) |

**Pažnja:** `C-z` u terminalu *suspenduje* Emacs, ne undo. Vratiš se sa `fg`.

## Compile workflow — ono glavno

| `C-c c` | kompajliraj (pita za komandu, pokreće iz korena projekta) |
|---|---|
| `C-c r` | ponovi poslednju, bez pitanja |
| `M-g n` | sledeća greška |
| `M-g p` | prethodna greška |
| `C-c k` | prekini kompajliranje |
| `C-c s` | rg pretraga kroz projekat (isti mehanizam, `M-g n` radi) |

Detaljno uputstvo: `COMPILE.md`.

## Vim → Emacs

### Fajlovi
| Vim | Emacs | |
|---|---|---|
| `:w` | `C-x C-s` | sačuvaj |
| `:q` | `C-x C-c` | izađi |
| `:e fajl` | `C-x C-f` | otvori (ido: kucaj deo imena) |
| `:ls` | `C-x b` | prebaci bafer |
| `:bd` | `C-x k` | zatvori bafer |
| `gf` | `C-x C-g` | otvori fajl pod kursorom (`#include "foo.h"`) |

### Kretanje
| Vim | Emacs | |
|---|---|---|
| `h j k l` | strelice rade normalno | ili `C-b C-n C-p C-f` |
| `w` / `b` | `M-f` / `M-b` | reč napred/nazad |
| `0` / `$` | `C-a` / `C-e` | početak/kraj linije |
| `gg` / `G` | `M-<` / `M->` | početak/kraj fajla |
| `C-d` / `C-u` | `C-v` / `M-v` | stranica dole/gore |
| `:42` | `M-g g 42` | skoči na liniju |
| `]]` | `C-c i m` | **imenu** — skok na funkciju (bez LSP-a, ovo koristiš) |

Relativni brojevi linija su uključeni — `M-5 C-n` ide 5 linija dole.

### Izmene
| Vim | Emacs | |
|---|---|---|
| `u` | `C-/` | undo |
| `C-r` | `C-g` pa `C-/` | redo (vidi dole) |
| `D` | `C-k` | obriši do kraja linije |
| `yy p` | `C-,` | **dupliraj liniju** |
| `ddp` | `M-n` / `M-p` | **pomeri liniju dole/gore** |
| `p` | `C-y` | nalepi |
| `dw` | `M-d` | obriši reč |

### Selekcija
`C-<space>` marker → pomeri kursor → `C-w` iseci · `M-w` kopiraj · `C-y` nalepi
`C-x h` = ceo bafer (Vim `ggVG`)

### Pretraga
| Vim | Emacs | |
|---|---|---|
| `/` | `C-s` | traži napred (`C-s` opet = sledeći) |
| `?` | `C-r` | traži nazad |
| `:%s/a/b/g` | `M-%` | zameni (`y`/`n`/`!`) |
| `:grep` | `C-c s` | rg kroz projekat |

### Prozori
| `:sp` | `C-x 2` | | `:vs` | `C-x 3` |
|---|---|---|---|---|
| `C-w w` | `C-x o` | | `C-w hjkl` | `S-<strelice>` |
| `:only` | `C-x 1` | | `:close` | `C-x 0` |

### Multiple cursors (nemaš u Vimu)
| `C->` | sledeća pojava reči pod kursorom |
|---|---|
| `C-<` | prethodna |
| `C-c C-<` | sve pojave odjednom |
| `C-S-c C-S-c` | kursor na svaku liniju selekcije |

## Git (magit)
`C-c m s` status · `C-c m l` log

U statusu: `s` stage · `u` unstage · `c c` commit (pa `C-c C-c` potvrdi) ·
`P p` push · `F p` pull · `?` pomoć · `q` izlaz

## Kad zaglaviš
| `C-g` | prekini |
|---|---|
| `M-x` | pokreni komandu po imenu (smex — sortiran po korišćenju) |
| `C-h k` + taster | "šta radi ovaj taster?" |
| `C-h t` | zvanični tutorial, 20 minuta |

## Undo/redo

Emacs nema redo pokazivač. **Undo je i sam izmena koja se upisuje u istoriju.**

- `C-/` · `C-_` · `C-x u` — undo
- `C-?` · `C-M-_` — pravi redo (`C-?` često ne radi u terminalu — DEL)
- **Redo bez prečice:** `C-g` (prekine niz), pa `C-/` — sad undo poništava
  tvoje undo-e, što je redo

Prednost nad Vimom: ništa se ne baca, nema izgubljene redo grane.
Zbunjuje: ako usred undo-vanja pomeriš kursor, prekinuo si niz.

## Autocomplete

Company iskače posle 2 znaka. **Nije semantički** — nudi reči koje već
postoje u otvorenim baferima. `TAB`/`RET` prihvata, `C-n`/`C-p` bira,
`C-g` odbija.
