;;; init.el --- Tsoding-style config  -*- lexical-binding: t; -*-
;;
;; Filozofija: sve eksplicitno, nista magicno. Bez LSP-a, bez tree-sitter-a.
;; Highlighting ide preko regexp-a, navigacija preko imenu/grep-a, a greske
;; preko compile bafera. Jezici: C i Go.

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(add-to-list 'load-path (expand-file-name "local/" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "rc/" user-emacs-directory))

(load (expand-file-name "rc/rc.el" user-emacs-directory))
(load (expand-file-name "rc/misc-rc.el" user-emacs-directory))
(load (expand-file-name "rc/compile-rc.el" user-emacs-directory))

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

;; Naysayer -- paleta iz editora Jonathana Blowa.
;; Menjanje teme: zameni ime ovde pa `emacs-restart'.
;; Instalirana je i gruber-darker ako hoces nazad.
(rc/require-theme 'naysayer)

;; Relativni brojevi linija -- Vim navika, i korisni su za M-<broj> skokove.
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;;; --------------------------------------------------------------------
;;; ido + smex -- completion stare skole
;;; --------------------------------------------------------------------
;; ido: pretraga po baferima i fajlovima. Kucaj deo imena, C-s / C-r
;; ciklaju kroz ponudjeno, RET potvrdjuje.
(rc/require 'smex 'ido-completing-read+)

(require 'ido-completing-read+)

(ido-mode 1)
(ido-everywhere 1)
(ido-ubiquitous-mode 1)
(setq ido-enable-flex-matching t)

;; smex = M-x sortiran po tome sta najcesce koristis.
(global-set-key (kbd "M-x") #'smex)
(global-set-key (kbd "C-c C-c M-x") #'execute-extended-command) ; original

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
