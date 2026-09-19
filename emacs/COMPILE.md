# Compile workflow

Ovo je srce Tsoding-ovog načina rada. Nema LSP-a, nema jezičke integracije —
postoji samo jedna ideja, i ona pokriva **svaki** jezik i **svaki** alat.

## Mentalni model

Emacs ne zna da kompajlira. On radi tri stvari:

1. pokrene shell komandu koju mu ti zadaš
2. uhvati njen izlaz u bafer `*compilation*`
3. **parsira taj izlaz** tražeći oblik `fajl:linija:kolona: poruka`

To je sve. Sve što ispisuje greške u tom formatu automatski postaje
klikabilna lista: `gcc`, `go`, `make`, `cargo`, `tsc`, `grep`, `rg`,
tvoj `build.sh`, tvoj Python skript.

Zato Tsoding ne treba LSP da bi video greške — kompajler je već najbolji
mogući linter, samo mu treba prikaz.

## Osnovna petlja

```
C-c c     pokreni kompajliranje  (ponudi komandu, izmeni je, RET)
M-g n     skoči na sledeću grešku
          ... popravi ...
C-c r     ponovi istu komandu, bez pitanja
```

Ovo je 90% posla. Naučiš ove tri prečice i imaš ceo workflow.

## Detaljno

### Pokretanje — `C-c c`

Emacs ponudi komandu u minibuffer-u. Prvi put je `make `. Obriši je i
otkucaj šta hoćeš:

```
Compile command: gcc -Wall -Wextra -o main main.c
```

`RET` pokreće. Otvara se `*compilation*` prozor sa izlazom.

**Gde se pokreće:** iz **korena projekta**, ne iz foldera fajla koji uređuješ.
Config se penje uz stablo tražeći `Makefile`, `go.mod`, `build.sh` ili `.git`.
Znači možeš biti u `src/net/http/server.c` i `C-c c` će naći Makefile na vrhu.

Sa `C-u C-c c` pokreće iz trenutnog foldera umesto iz korena.

**Emacs pamti komandu po baferu.** Sledeći `C-c c` u istom fajlu ti nudi
istu komandu.

### Kretanje kroz greške

Bilo gde u Emacsu, ne moraš biti u compile baferu:

| | |
|---|---|
| `M-g n` | sledeća greška — skoči na tu liniju u kodu |
| `M-g p` | prethodna |
| `C-x \`` | isto što i `M-g n` (klasična prečica, starija) |

Unutar `*compilation*` bafera:

| | |
|---|---|
| `RET` | skoči na grešku pod kursorom |
| `n` / `p` | sledeća/prethodna greška **bez** skakanja (samo pregled) |
| `g` | ponovi kompajliranje |
| `q` | zatvori prozor |
| `C-c k` | prekini kompajliranje koje traje |

### Ponavljanje — `C-c r`

`rc/recompile` ponovo pokreće **poslednju** komandu, iz **istog** foldera,
bez ijednog pitanja. Ovo pritiskaš na svakih 20 sekundi dok radiš.

Petlja u praksi:
```
C-c c    (jednom, zadaš komandu)
C-c r  →  M-g n  →  popraviš  →  C-c r  →  M-g n  →  popraviš  →  C-c r
```

## Komanda po projektu — `.dir-locals.el`

Da ne kucaš komandu svaki put, stavi u koren projekta fajl `.dir-locals.el`:

```elisp
((nil . ((compile-command . "make -j8"))))
```

Za različite komande po tipu fajla:

```elisp
((simpc-mode . ((compile-command . "make debug")))
 (go-mode    . ((compile-command . "go build ./... && go test ./..."))))
```

Emacs će prvi put pitati da li da veruje tim vrednostima — odgovori `!`
(zapamti za ubuduće).

Za Go je već podešeno u configu: `go build ./... && go vet ./...`.

## Zašto ovo zamenjuje LSP

| LSP daje | Ovde koristiš |
|---|---|
| greške u realnom vremenu | `C-c r` — kompajler, 100% tačan |
| goto definition | `C-c i m` (imenu) ili `C-c s` (rg) |
| find references | `C-c s` — rg kroz projekat |
| rename symbol | `C-c s` pa multiple cursors, ili `sed` |
| autocomplete | company — iz teksta bafera |

Kompromis je iskren: gubiš trenutnu povratnu informaciju i semantičko
preimenovanje. Dobijaš to da ništa ne indeksira u pozadini, ništa se ne
kvari, i radi identično za jezik koji si napisao juče.

## Grep koristi isti mehanizam

`C-c s` pokreće `rg --vimgrep` iz korena projekta. Pošto `rg` ispisuje
`fajl:linija:kolona:tekst` — isti format kao gcc — rezultati su ista takva
lista. **`M-g n` radi i kroz rezultate pretrage.**

To je ista mašinerija, i to je poenta celog pristupa.

## Kad izlaz nije u standardnom formatu

Ako tvoj alat ispisuje greške drugačije, naučiš Emacs regexp-om:

```elisp
(add-to-list 'compilation-error-regexp-alist
             '("^\\([^:]+\\) line \\([0-9]+\\)" 1 2))
;;              putanja do fajla     broj linije
;;              grupa 1 = fajl, grupa 2 = linija
```

Tsoding ovo ima za Pascal. Ti verovatno nikad nećeš morati — gcc i go su
već pokriveni.
