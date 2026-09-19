;;; compile-rc.el --- Compile workflow  -*- lexical-binding: t; -*-
;;
;; Ideja: Emacs ne zna da kompajlira. On samo pokrene shell komandu,
;; uhvati izlaz u bafer, i PARSIRA ga trazeci "fajl:linija:kolona: poruka".
;; Sve sto daje gresku u tom formatu -- gcc, go, make, grep, cargo, tvoj
;; skript -- automatski postaje klikabilna lista gresaka.
;;
;; To je cela magija. Nema jezicke integracije, nema plugina po jeziku.

(require 'compile)
(require 'ansi-color)

;; Prati izlaz dok se kompajlira, ali stani na prvoj gresci.
;; (Tsoding koristi `t' = prati do kraja. Probaj oba, promeni po ukusu.)
(setq compilation-scroll-output 'first-error)

;; Ne pitaj "Save file?" za svaki bafer pre kompajliranja -- samo snimi.
(setq compilation-ask-about-save nil)

;; Podrazumevana komanda. `M-x compile' je ponudi, ti je izmenis po potrebi.
;; Emacs pamti poslednju komandu po baferu.
(setq compile-command "make ")

;; gcc/clang bojе izlaz ako misle da pricaju sa terminalom. Compilation
;; bafer nije terminal, ali `make' ume da prosledi -fdiagnostics-color.
;; Bez ovoga bi video sirove ESC[31m sekvence umesto boja.
(defun rc/colorize-compilation-buffer ()
  (let ((inhibit-read-only t))
    (ansi-color-apply-on-region compilation-filter-start (point))))

(add-hook 'compilation-filter-hook #'rc/colorize-compilation-buffer)

;;; --------------------------------------------------------------------
;;; Kompajliranje iz korena projekta
;;; --------------------------------------------------------------------
;; Problem: otvoris src/foo/bar.c i pozoves `compile'. Emacs pokrene `make'
;; u src/foo/, gde nema Makefile-a. Ove funkcije penju se uz stablo dok ne
;; nadju "sidro" (Makefile, go.mod, .git) i kompajliraju odatle.

(defun rc/parent-directory (path)
  (file-name-directory (directory-file-name path)))

(defun rc/root-anchor (path anchor)
  "Penji se od PATH nagore dok ne nadjes folder koji sadrzi ANCHOR."
  (cond
   ((string= anchor "") nil)
   ((file-exists-p (concat (file-name-as-directory path) anchor)) path)
   ((string-equal path "/") nil)
   (t (rc/root-anchor (rc/parent-directory path) anchor))))

(defvar rc/compile-anchors '("Makefile" "makefile" "go.mod" "build.sh" ".git")
  "Fajlovi po kojima se prepoznaje koren projekta, redom po prioritetu.")

(defun rc/project-root ()
  "Vrati NAJBLIZI folder nagore koji sadrzi neki od `rc/compile-anchors'.

Bitno je da se penje po nivoima, a ne po tipu sidra. Stara verzija je
trazila prvo sve \"Makefile\" pa onda sve \"go.mod\", pa je iz
repo/podprojekat/ (koji ima go.mod) preskakala na repo/ samo zato sto
repo/ ima Makefile -- i `C-c c' bi pokretao build iz pogresnog foldera."
  (let ((dir (expand-file-name default-directory))
        (found nil))
    (while (and dir (not found))
      (when (seq-some (lambda (a)
                        (file-exists-p (expand-file-name a dir)))
                      rc/compile-anchors)
        (setq found dir))
      (let ((parent (rc/parent-directory dir)))
        (setq dir (if (equal parent dir) nil parent))))
    (or found default-directory)))

(defun rc/compile (command)
  "Kao `compile', ali se pokrece iz korena projekta.
Sa prefiksom (C-u) pokrece se iz trenutnog foldera."
  (interactive
   (list (compilation-read-command compile-command)))
  (let ((default-directory (if current-prefix-arg
                               default-directory
                             (rc/project-root))))
    (message "Kompajliram u %s" default-directory)
    (compile command)))

(defun rc/recompile ()
  "Ponovi poslednju kompilaciju, bez pitanja."
  (interactive)
  (if (get-buffer "*compilation*")
      (with-current-buffer "*compilation*" (recompile))
    (call-interactively #'rc/compile)))

;;; --------------------------------------------------------------------
;;; Bindinzi
;;; --------------------------------------------------------------------
(global-set-key (kbd "C-c c") #'rc/compile)     ; pokreni (pita za komandu)
(global-set-key (kbd "C-c r") #'rc/recompile)   ; ponovi istu, bez pitanja
(global-set-key (kbd "M-g n") #'next-error)     ; sledeca greska  (ugradjeno)
(global-set-key (kbd "M-g p") #'previous-error) ; prethodna       (ugradjeno)
(global-set-key (kbd "C-c k") #'kill-compilation)

;;; --------------------------------------------------------------------
;;; Go: compile-command po baferu
;;; --------------------------------------------------------------------
;; U Go projektu `make' obicno ne postoji, pa podesi razumnu komandu.
;; `setq-local' znaci "samo u ovom baferu" -- C bafer zadrzava `make'.
(defun rc/go-compile-defaults ()
  (setq-local compile-command "go build ./... && go vet ./..."))

(add-hook 'simpgo-mode-hook #'rc/go-compile-defaults)

;;; --------------------------------------------------------------------
;;; grep preko ripgrep-a
;;; --------------------------------------------------------------------
;; Kljucna stvar za razumeti: grep rezultati i greske iz kompajlera idu
;; kroz ISTU masineriju. `rg --vimgrep' ispisuje "fajl:linija:kolona:tekst",
;; sto je isti format koji gcc koristi za greske. Zato M-g n radi i ovde.

(require 'grep)

(defun rc/rg (pattern)
  "Trazi PATTERN kroz ceo projekat pomocu ripgrep-a."
  (interactive
   (list (read-string "rg: " (thing-at-point 'symbol t))))
  (let ((default-directory (rc/project-root)))
    (compilation-start
     (format "rg --vimgrep --smart-case -- %s" (shell-quote-argument pattern))
     #'grep-mode)))


;;; --------------------------------------------------------------------
;;; "Gde je ovo definisano" bez LSP-a
;;; --------------------------------------------------------------------
;; Obican grep na ime daje SVE pojave, a definicija je jedna od stotinu.
;; Trik: ne trazi ime, nego OBLIK DEFINICIJE -- "func Ime", "type Ime",
;; "Ime =", "#define Ime". Jedan regexp po jeziku i pogodaka je troje
;; umesto sto.

(defun rc/def-pattern (sym)
  "Regexp koji hvata deklaracije SYM-a u trenutnom jeziku."
  (let ((s (regexp-quote sym)))
    (pcase major-mode
      ('simpgo-mode
       ;; func Ime( | func (r T) Ime( | type Ime | const/var Ime
       ;; | Ime = ... | Ime := ... | Ime Tip = iota
       (concat "(func|type|const|var)\\s+(\\([^)]*\\)\\s*)?" s "\\b"
               "|^\\s*" s "\\s+[\\w\\[\\]\\*\\.]+\\s*=" 
               "|^\\s*" s "\\s*:?="))
      ('simpc-mode
       ;; #define Ime | tip Ime( | struct/enum/union Ime | typedef ... Ime;
       ;; Kljucno: linija mora POCETI slovom (povratni tip), ne razmakom --
       ;; inace hvata svaki uvuceni POZIV funkcije umesto definicije.
       (concat "^#\\s*define\\s+" s "\\b"
               "|^[A-Za-z_][\\w \\t\\*]*\\b" s "\\s*\\("
               "|^\\s*(struct|enum|union)\\s+" s "\\s*\\{"
               "|^\\s*typedef\\b.*\\b" s "\\s*;"))
      (_ (concat "(def|function|class|struct|type|const|var)\\s+" s "\\b")))))

(defun rc/dep-dirs ()
  "Gde zive zavisnosti za trenutni jezik."
  (pcase major-mode
    ('simpgo-mode
     (let ((cache (string-trim (shell-command-to-string "go env GOMODCACHE 2>/dev/null"))))
       (when (and (not (string-empty-p cache)) (file-directory-p cache))
         (list cache))))
    ('simpc-mode
     (seq-filter #'file-directory-p '("/usr/include" "/usr/local/include")))
    (_ nil)))

(defun rc/rg-def (sym &optional with-deps)
  "Nadji gde je SYM definisan. Sa prefiksom (C-u) trazi i po zavisnostima.

Obican `rc/rg' (C-c s) daje sve pojave; ovo trazi samo oblik deklaracije."
  (interactive
   (list (read-string "definicija: " (thing-at-point 'symbol t))
         current-prefix-arg))
  (let* ((dirs (if with-deps (rc/dep-dirs) nil))
         (default-directory (rc/project-root))
         (where (if dirs
                    (mapconcat #'shell-quote-argument (cons "." dirs) " ")
                  "."))
         (cmd (format "rg --vimgrep --no-heading -e %s -- %s"
                      (shell-quote-argument (rc/def-pattern sym))
                      where)))
    (message "%s" (if dirs "trazim i po zavisnostima..." "trazim u projektu..."))
    (compilation-start cmd #'grep-mode)))

(global-set-key (kbd "C-c d") #'rc/rg-def)

;; Go: `go doc' je najbrzi i najtacniji odgovor za sve iz stdlib-a i
;; zavisnosti -- ne trazi po fajlovima, pita sam Go.
(defun rc/go-doc (args)
  "Pokazi `go doc' za ARGS (npr. \"termbox ColorDefault\" ili \"fmt.Println\").

Radi za stdlib i za zavisnosti -- ne trazi po fajlovima nego pita Go."
  (interactive (list (read-string "go doc: " (thing-at-point 'symbol t))))
  (let (;; `go doc' mora da se pokrene iz foldera sa go.mod, inace ne zna
        ;; koje su zavisnosti. Koren projekta nije nuzno taj folder.
        (default-directory (or (rc/root-anchor default-directory "go.mod")
                               (rc/project-root)))
        ;; `go doc' uzima 1-2 odvojena argumenta. Deli po razmacima i
        ;; prosledi kao listu -- ne kroz shell, pa nema ni quoting problema.
        (parts (split-string (string-trim args) "[ \t]+" t)))
    (with-current-buffer (get-buffer-create "*go doc*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (apply #'call-process "go" nil t nil "doc" parts)
        (goto-char (point-min))
        (view-mode 1))
      (display-buffer (current-buffer)))))

(global-set-key (kbd "C-c D") #'rc/go-doc)

(provide 'compile-rc)
