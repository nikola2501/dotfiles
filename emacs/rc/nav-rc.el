;;; nav-rc.el --- Kretanje po kodu i projektu  -*- lexical-binding: t; -*-
;;
;; Dve stvari, obe ugradjene u Emacs 30 -- nijedan paket:
;;
;;   project.el   "otvori fajl iz ovog projekta" (C-x p f)
;;   winner       vrati raspored prozora kakav je bio (C-c <levo>)
;;
;; Plus otvaranje dokumentacije samog configa iz bilo kog foldera.
;;
;; Izbacen recentf: posao mu vec rade `C-x p f' (fajlovi projekta),
;; `C-x b' (otvoreni baferi) i `M-p' u `C-x C-f' (istorija putanja, koju
;; savehist ionako cuva izmedju sesija).


;;; --------------------------------------------------------------------
;;; project.el
;;; --------------------------------------------------------------------
;; Emacs podrazumevano prepoznaje projekat preko vc-a. Mi smo vc ugasili
;; (vidi misc-rc.el), pa `project-current' vraca nil i CEO `C-x p' prefiks
;; ne radi. Mereno: sa vc-handled-backends nil, project-current = nil.
;;
;; Resenje je sopstveni backend od deset linija. Koristi ISTA sidra kao
;; `rc/compile' (rc/compile-anchors iz compile-rc.el), pa su koren za
;; build i koren za pretragu uvek isti folder.

(defun rc/project-try (dir)
  "Vrati projekat za DIR, ili nil. Kaci se na `project-find-functions'."
  (let ((root (locate-dominating-file
               dir
               (lambda (d)
                 (seq-some (lambda (a) (file-exists-p (expand-file-name a d)))
                           rc/compile-anchors)))))
    (when root (cons 'rc (expand-file-name root)))))

;; `project.el' se NE ucitava pri startu -- meren je na 11 ms. Ucita se
;; sam kad prvi put pozoves `C-x p f'; tek tada treba definisati metode.
;; Hook ispod se kaci odmah, `add-hook' ne zahteva da fajl bude ucitan.
(with-eval-after-load 'project
  (cl-defmethod project-root ((project (head rc)))
    (cdr project))

  ;; Listanje fajlova ide kroz ripgrep umesto kroz `find'. Rg cita
  ;; .gitignore, pa ne nudi build artefakte, i brzi je: mereno na ovom
  ;; repou, find 20 ms -> rg 6 ms. Na velikom repou razlika je veca.
  (cl-defmethod project-files ((project (head rc)) &optional _dirs)
    (let ((default-directory (cdr project)))
      (mapcar (lambda (f) (expand-file-name f default-directory))
              (split-string
               (shell-command-to-string
                "rg --files --hidden --glob '!.git' 2>/dev/null")
               "\n" t)))))

(add-hook 'project-find-functions #'rc/project-try)

;;; --------------------------------------------------------------------
;;; winner -- undo za raspored prozora
;;; --------------------------------------------------------------------
;; Splitujes ekran na tri dela, pa te `C-x 1' vrati na jedan. winner
;; pamti prethodne rasporede: C-c <levo> vraca, C-c <desno> ponavlja.
(winner-mode 1)

;;; --------------------------------------------------------------------
;;; Dokumentacija configa iz bilo kog foldera
;;; --------------------------------------------------------------------
;; `user-emacs-directory' je ~/.config/emacs, a tamo su simlinkovi na
;; dotfiles repo. `file-truename' vodi na pravi fajl, pa ako nesto
;; ispravis dok citas, ispravio si ga u repou a ne u simlinku.

(defun rc/open-doc (name)
  "Otvori NAME iz `user-emacs-directory' u view-modu (q zatvara)."
  (let ((file (file-truename (expand-file-name name user-emacs-directory))))
    (if (file-exists-p file)
        (progn (find-file file)
               (view-mode 1))
      (message "Nema fajla: %s" file))))

(defun rc/cheatsheet ()
  "Precice: Vim -> Emacs tabela i kretanje po kodu."
  (interactive) (rc/open-doc "CHEATSHEET.md"))

(defun rc/doc-compile ()
  "Detaljno uputstvo za compile workflow."
  (interactive) (rc/open-doc "COMPILE.md"))

(defun rc/doc-readme ()
  "Pregled configa -- struktura i spisak paketa."
  (interactive) (rc/open-doc "README.md"))

(defun rc/open-init ()
  "Otvori init.el za izmenu."
  (interactive)
  (find-file (file-truename (expand-file-name "init.el" user-emacs-directory))))

;; C-c h je slobodan prefiks (C-h je help, ovo nije isto).
;; Pritisni C-c h i zastani -- which-key izlista sta moze da sledi.
(global-set-key (kbd "C-c h c") #'rc/cheatsheet)
(global-set-key (kbd "C-c h k") #'rc/doc-compile)
(global-set-key (kbd "C-c h r") #'rc/doc-readme)
(global-set-key (kbd "C-c h i") #'rc/open-init)

(provide 'nav-rc)
