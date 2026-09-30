;;; init.el --- Tsoding-style config  -*- lexical-binding: t; -*-
;;
;; Filozofija: sve eksplicitno, nista magicno. Bez LSP-a, bez tree-sitter-a.
;; Highlighting ide preko regexp-a, navigacija preko imenu/grep-a, a greske
;; preko compile bafera. Jezici: C, Go i Odin.

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(add-to-list 'load-path (expand-file-name "local/" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "rc/" user-emacs-directory))

(load (expand-file-name "rc/rc.el" user-emacs-directory))
(load (expand-file-name "rc/misc-rc.el" user-emacs-directory))
(load (expand-file-name "rc/compile-rc.el" user-emacs-directory))
(load (expand-file-name "rc/nav-rc.el" user-emacs-directory))
(load (expand-file-name "rc/eglot-rc.el" user-emacs-directory))

;;; --------------------------------------------------------------------
;;; Izgled
;;; --------------------------------------------------------------------
(defun rc/get-default-font ()
  (cond
   ((eq system-type 'windows-nt) "Consolas-13")
   ((eq system-type 'darwin)     "Iosevka-15")
   ((eq system-type 'gnu/linux)  "Iosevka-14")))

;; Vazi samo za GUI frame. U terminalu (-nw) font daje sam terminal.

(add-to-list 'default-frame-alist `(font . ,(rc/get-default-font)))

(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)
(column-number-mode 1)
(show-paren-mode 1)

;; Matrix -- port moje Sublime teme "Cyanide - Matrix", vidi
;; local/matrix-theme.el. Nije paket, pa ide `load-theme' a ne
;; `rc/require-theme'; `t' znaci bez "Really load?" pitanja.
;; Menjanje teme: zameni ime ovde pa `emacs-restart'.
(add-to-list 'custom-theme-load-path (expand-file-name "local/" user-emacs-directory))
(load-theme 'matrix t)

;; Naysayer (paleta iz editora Jonathana Blowa) ostaje instaliran. Nazad:
;; zameni `(load-theme 'matrix t)' gore ovim. naysayer-theme.el nema
;; `lexical-binding' cookie, pa Emacs 31 iskoci *Warnings* -- let to gasi.
;;   (let ((warning-suppress-types (cons '(files missing-lexbind-cookie) warning-suppress-types)))
;;     (rc/require-theme 'naysayer))

;; Relativni brojevi linija -- Vim navika, i korisni su za M-<broj> skokove.
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;;; --------------------------------------------------------------------
;;; Completion -- vertico + orderless + marginalia
;;; --------------------------------------------------------------------
;; Tsoding koristi ido + smex. ido lista kandidate VODORAVNO i ne pokazuje
;; precice, sto je u redu ako ih znas napamet. Ovo je citljivija varijanta:
;;
;;   vertico     spisak odozdo, jedan kandidat po liniji, strelice biraju
;;   orderless   kucaj delove bilo kojim redom: "comp proj" nalazi
;;               project-compile
;;   marginalia  desno od svake komande pise NJENA PRECICA i opis
;;
;; Ta treca je ono sto uci precice usput: svaki put kad nesto pokrenes
;; preko M-x, vidis kojim tasterom si to mogao.
(rc/require 'vertico 'orderless 'marginalia)

(require 'vertico)
(require 'orderless)
(require 'marginalia)

(vertico-mode 1)
(marginalia-mode 1)

(setq vertico-count 15                  ; koliko kandidata prikazati
      vertico-cycle t)

(setq completion-styles '(orderless basic)
      completion-category-overrides '((file (styles basic partial-completion))))

;; M-x ostaje ugradjeni execute-extended-command -- vertico ga preuzima.
;; Emacs sam pamti istoriju, pa se ono sto koristis penje na vrh.
(setq history-length 200)
(savehist-mode 1)

;; Posle svake komande pokrenute preko M-x, Emacs javi u echo areji
;; "You can run the command X with KEY" -- jos jedan nacin da naucis precice.
(setq suggest-key-bindings 5)

;;; --------------------------------------------------------------------
;;; C -- simpc-mode
;;; --------------------------------------------------------------------
;; Tsoding-ov mod umesto ugradjenog cc-mode. Vidi local/simpc-mode.el.
(require 'simpc-mode)
(add-to-list 'auto-mode-alist '("\\.[hc]\\(pp\\)?\\'" . simpc-mode))

;;; --------------------------------------------------------------------
;;; Go -- simpgo-mode
;;; --------------------------------------------------------------------
;; Nas mod umesto go-mode paketa. Vidi local/simpgo-mode.el.
;; Izmereno na Go fajlu od 6000 linija, bojenje vidljivog ekrana:
;;   go-mode      2.49 ms
;;   simpgo-mode  0.11 ms   (23x brze)
;; Gubimo bojenje imena funkcija i promenljivih -- ionako ih ne bojimo
;; ni u C-u. gofmt na snimanju radi, poziva spoljni program direktno.
(require 'simpgo-mode)
(add-to-list 'auto-mode-alist '("\\.go\\'" . simpgo-mode))
(add-hook 'before-save-hook #'simpgo-format-before-save)

;; go.mod nije Go kod; conf-mode je dovoljan da ne bude neobojen.
(add-to-list 'auto-mode-alist '("/go\\.\\(mod\\|sum\\|work\\)\\'" . conf-mode))

;;; --------------------------------------------------------------------
;;; Odin -- simpodin-mode
;;; --------------------------------------------------------------------
;; Isti recept kao simpgo-mode. Vidi local/simpodin-mode.el.
;; Nema formatiranja na snimanju: Odin nema kanonski formatter kao gofmt.
;; Kad je LSP upaljen (C-c l l), M-x eglot-format radi kroz ols.
(require 'simpodin-mode)
(add-to-list 'auto-mode-alist '("\\.odin\\'" . simpodin-mode))

;;; --------------------------------------------------------------------
;;; Company -- dopuna iz teksta bafera
;;; --------------------------------------------------------------------
;; Bez LSP-a ovo nije semanticko dopunjavanje. Company gleda reci koje vec
;; postoje u otvorenim baferima i nudi ih. Iznenadjujuce korisno.
(rc/require 'company)
(require 'company)

(setq company-idle-delay 0.2
      company-minimum-prefix-length 2
      company-dabbrev-downcase nil
      ;; Default lista vuce company-bbdb (adresar), semantic, cmake, clang,
      ;; gtags, etags, oddmuse -- nista od toga ne koristis, a prolazi se
      ;; kroz celu listu pri svakoj dopuni.
      company-backends '(company-capf
                         company-files
                         (company-dabbrev-code company-keywords)
                         company-dabbrev)
      ;; Default je `all' = skeniraj SVE otvorene bafere. `t' = samo bafere
      ;; istog major moda, sto je ono sto zapravo hoces.
      company-dabbrev-other-buffers t)

(global-company-mode 1)

;;; --------------------------------------------------------------------
;;; Magit
;;; --------------------------------------------------------------------
(rc/require 'magit)

(setq magit-auto-revert-mode nil)

;; Default je da pre SVAKOG osvezavanja pita "Save file X?" za svaki
;; nesnimljen bafer iz repoa. Na `n' ne pamti odgovor, pa pita ponovo na
;; sledecu komandu -- i blokira ceo daemon dok ne odgovoris. Snimas sam.
(setq magit-save-repository-buffers nil)

;; "Tags: v1.2.3 (17)" red u statusu -- `git describe' pri svakom
;; osvezavanju. Mereno: ~60 od ~310 ms celog `g'.
(with-eval-after-load 'magit-status
  (remove-hook 'magit-status-headers-hook #'magit-insert-tags-header))

;; /usr/bin/git na macOS-u nije git nego xcrun shim koji pri SVAKOM pozivu
;; trazi pravi git. Magit na jedan RET u diffu pozove git ~27 puta.
;; Mereno iz Emacsa: shim 14 ms po pozivu, pravi git 3.3 ms.
(when (eq system-type 'darwin)
  (let ((git "/Library/Developer/CommandLineTools/usr/bin/git"))
    (when (file-executable-p git)
      (setq magit-git-executable git))))

;; Skok iz diffa u fajl bez gita. Magitov RET za jedan skok pozove git
;; ~27 puta: razresava range, trazi merge-base, pa otvara BLOB sa brancha
;; (read-only kopiju `fajl.~branch~'), a ne pravi fajl. Mereno: ~100-200 ms.
;; Ovde se sve cita iz diff bafera, koji vec zna fajl i broj linije:
;; 2-5 ms. Otvara PRAVI fajl iz worktree-a, pa mozes odmah da ga menjas.
;;
;; Cena: linija je iz commitovanog stanja. Ako fajl ima necommitovane
;; izmene iznad te linije, skok promasi za toliko linija. Na obrisanoj
;; liniji skace na mesto gde je bila. Ako fajla vise nema u worktree-u
;; (obrisan u diffu), pada na magitov blob -- bar vidis sta je bilo.
;; Stari RET (sa blobom) ostaje na M-x magit-diff-visit-file.
(defun rc/magit-visit-fast (&optional other-window)
  "Iz magit diffa otvori pravi fajl na liniji iz hunka. Bez git poziva."
  (interactive "P")
  (let* ((fsec (or (magit-diff--file-section) (user-error "Nije diff")))
         ;; default-directory diff bafera je koren repoa.
         (path (expand-file-name (oref fsec value)))
         (hunk (magit-diff--hunk-section))
         (line (and hunk (magit-diff-hunk-line hunk nil)))
         (col  (and hunk (magit-diff-hunk-column hunk nil))))
    (if (not (file-exists-p path))
        (call-interactively (if other-window
                                #'magit-diff-visit-file-other-window
                              #'magit-diff-visit-file))
      (if other-window (find-file-other-window path) (find-file path))
      (when line
        (goto-char (point-min))
        (forward-line (1- line))
        (move-to-column col)))))

(defun rc/magit-visit-fast-other-window ()
  "Kao `rc/magit-visit-fast', ali u drugom prozoru -- diff ostaje vidljiv."
  (interactive)
  (rc/magit-visit-fast t))

;; U terminalu C-RET stize kao obican RET, zato C-x 4 RET za drugi prozor
;; (standardni Emacs "4 = drugi prozor" prefiks, kao C-x 4 f). Ne `o':
;; to bi u diffu zaklonilo magitov `o' (submodule meni).
(with-eval-after-load 'magit-diff
  (define-key magit-diff-section-map (kbd "RET") #'rc/magit-visit-fast)
  (define-key magit-diff-section-map (kbd "<return>") #'rc/magit-visit-fast)
  (define-key magit-diff-section-map (kbd "C-x 4 RET") #'rc/magit-visit-fast-other-window)
  (define-key magit-diff-section-map (kbd "C-x 4 <return>") #'rc/magit-visit-fast-other-window))

(global-set-key (kbd "C-c m s") #'magit-status)
(global-set-key (kbd "C-c m l") #'magit-log)

;;; --------------------------------------------------------------------
;;; Multiple cursors
;;; --------------------------------------------------------------------
(rc/require 'multiple-cursors)

(global-set-key (kbd "C-S-c C-S-c") #'mc/edit-lines)
(global-set-key (kbd "C->")         #'mc/mark-next-like-this)
(global-set-key (kbd "C-<")         #'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-<")     #'mc/mark-all-like-this)

;;; --------------------------------------------------------------------
;;; Move text
;;; --------------------------------------------------------------------
(rc/require 'move-text)

(global-set-key (kbd "M-p") #'move-text-up)
(global-set-key (kbd "M-n") #'move-text-down)

;;; --------------------------------------------------------------------
;;; dired
;;; --------------------------------------------------------------------
(require 'dired-x)
(setq dired-listing-switches "-alh"
      dired-dwim-target t)

;;; --------------------------------------------------------------------
;;; grep -- zamena za "find references" bez LSP-a
;;; --------------------------------------------------------------------
;; Vidi rc/compile-rc.el -- rezultati grep-a koriste ISTI mehanizam kao
;; greske iz kompajlera: M-g n / M-g p skacu kroz njih.
(global-set-key (kbd "C-c s") #'rc/rg)

;;; --------------------------------------------------------------------
;;; macOS
;;; --------------------------------------------------------------------
(when (eq system-type 'darwin)
  ;; GUI Emacs na macOS-u ne nasledjuje PATH iz shell-a (launchd ga daje).
  ;; U terminalu ovo nije problem, ali ne skodi.
  (dolist (dir '("/opt/homebrew/bin" "/usr/local/bin" "~/go/bin"))
    (let ((d (expand-file-name dir)))
      (when (file-directory-p d)
        (setenv "PATH" (concat d ":" (getenv "PATH")))
        (add-to-list 'exec-path d))))

  ;; BSD ls ne podrzava sve GNU flagove koje dired ocekuje. Ako imas
  ;; coreutils (brew install coreutils), koristi gls.
  (let ((gls (executable-find "gls")))
    (when gls (setq insert-directory-program gls))))

(load custom-file t)
