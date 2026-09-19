;;; misc-rc.el --- Sitne funkcije i bindinzi  -*- lexical-binding: t; -*-
;;
;; Izbor korisnih funkcija iz Tsoding-ovog misc-rc.el, bez onoga sto ti
;; ne treba (ruski input, VNC hakovi, org linkovi, XML pretty-print).

(setq-default inhibit-splash-screen t
              make-backup-files nil      ; on ih prosto gasi
              auto-save-default nil
              create-lockfiles nil
              tab-width 4
              indent-tabs-mode nil)

(setq confirm-kill-emacs 'y-or-n-p)      ; da ne izletis slucajno

;; Iskljuci vc. Emacs za SVAKI otvoreni fajl pokrece
;;   git status --porcelain -z -- <fajl>
;; samo da bi ispisao "Git:main" u modeline. Na velikom repou ta komanda
;; sa pathspec-om gubi git-ov untracked kes i lstat-uje celo stablo:
;; izmereno 1086 ms na repou od 19G, dok status CELOG repoa traje 29 ms.
;; Otvaranje fajla: 1113 ms sa vc -> 8 ms bez njega.
;; Magit ionako ne koristi vc i radi sve sto ti treba (C-c m s).
(setq vc-handled-backends nil)

(windmove-default-keybindings)           ; S-<strelice> izmedju prozora

;; which-key: pritisnes prefiks (C-x, C-c) i zastanes -- iskoci spisak svega
;; sto moze da sledi. Ugradjen je u Emacs 30, nije paket.
;; Tsoding ga nema, ali on zna svoje precice napamet.
(setq which-key-idle-delay 0.4             ; default je 1.0s -- predugo
      which-key-idle-secondary-delay 0.05  ; unutar istog prefiksa, odmah
      which-key-max-description-length 40)
(which-key-mode 1)

;; Otvori fajl ciju putanju kursor dodiruje (npr. #include "foo.h")
(global-set-key (kbd "C-x C-g") #'find-file-at-point)

;; Skok na funkciju u trenutnom fajlu. BEZ LSP-a ovo ti je glavna
;; navigacija -- imenu cita bafer i izlista definicije.
(global-set-key (kbd "C-c i m") #'imenu)

(defun rc/duplicate-line ()
  "Dupliraj trenutnu liniju."
  (interactive)
  (let ((column (- (point) (line-beginning-position)))
        (line (let ((s (thing-at-point 'line t)))
                (if s (string-remove-suffix "\n" s) ""))))
    (move-end-of-line 1)
    (newline)
    (insert line)
    (move-beginning-of-line 1)
    (forward-char column)))

(global-set-key (kbd "C-,") #'rc/duplicate-line)

(defun rc/buffer-file-name ()
  (if (equal major-mode 'dired-mode)
      default-directory
    (buffer-file-name)))

(defun rc/put-file-name-on-clipboard ()
  "Stavi putanju trenutnog fajla u clipboard."
  (interactive)
  (let ((filename (rc/buffer-file-name)))
    (when filename
      (kill-new filename)
      (message filename))))

(defun rc/unfill-paragraph ()
  "Suprotno od `fill-paragraph' -- spoji pasus u jednu liniju."
  (interactive)
  (let ((fill-column most-positive-fixnum))
    (fill-paragraph nil)))

(global-set-key (kbd "C-c M-q") #'rc/unfill-paragraph)

;; Brisanje trailing whitespace-a na snimanju + vizuelni prikaz.
(defun rc/set-up-whitespace-handling ()
  (interactive)
  (whitespace-mode 1)
  (add-to-list 'write-file-functions #'delete-trailing-whitespace))

;; Tsoding ovo kaci rucno na ~20 modova (i u jednom slucaju pogresi ime
;; hook-a pa mu ne radi za elisp). Jedan `prog-mode-hook' radi isto.
(add-hook 'prog-mode-hook #'rc/set-up-whitespace-handling)

;; SAMO trailing whitespace. Ne markiramo tabove: Go se po definiciji
;; uvlaci tabovima (gofmt), pa bi svaka uvucena linija dobila marker.
(setq whitespace-style '(face trailing))

;;; --------------------------------------------------------------------
;;; Performanse
;;; --------------------------------------------------------------------
;; Posteno: od svega ovde, jedino je iskljucivanje vc-a (gore) dalo merljivu
;; razliku (1113 ms -> 7 ms po otvorenom fajlu). Ostalo su standardna
;; podesavanja koja pomazu interaktivnom iscrtavanju; taj deo se ne moze
;; izmeriti iz batch moda, pa stoje bez dokaza. Nisu stetna.

;; GC: default je 800 KB. Izmereno je da font-lock posao provede 5.5%
;; vremena u GC, ali dizanje na 32 MB NIJE dalo merljivo ubrzanje tog
;; posla. Pomaze kod dugih interaktivnih sesija, gde se alokacije gomilaju.
(setq gc-cons-threshold (* 32 1024 1024)
      gc-cons-percentage 0.2)

;; Bidirekcioni tekst (arapski, hebrejski). Ne koristis ga, a Emacs pri
;; svakom iscrtavanju proverava da li linija ima RTL karaktere.
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Ne boji ekran dok kucas brzo -- sacekaj da prestanes.
(setq redisplay-skip-fontification-on-input t)

;; Skroluj bez preciznog racunanja pozicije (neprimetno, a brze).
(setq fast-but-imprecise-scrolling t)

;; Citaj izlaz procesa u vecim komadima. Bitno za `compile' sa mnogo izlaza.
(setq read-process-output-max (* 1024 1024)
      process-adaptive-read-buffering nil)

;; Ne proveravaj auto-mode-alist i za mala i za velika slova.
(setq auto-mode-case-fold nil)

;; vc je iskljucen (gore), pa mu skloni i hook -- nema sta da radi.
(remove-hook 'find-file-hook #'vc-refresh-state)

(provide 'misc-rc)
