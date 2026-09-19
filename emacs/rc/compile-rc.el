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
  "Vrati koren projekta, ili trenutni folder ako ga nema."
  (or (seq-some (lambda (anchor) (rc/root-anchor default-directory anchor))
                rc/compile-anchors)
      default-directory))

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

(add-hook 'go-mode-hook #'rc/go-compile-defaults)

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

(provide 'compile-rc)
