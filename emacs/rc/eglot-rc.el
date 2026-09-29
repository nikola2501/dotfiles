;;; eglot-rc.el --- LSP na zahtev  -*- lexical-binding: t; -*-
;;
;; Filozofija ostaje bez LSP-a. Ovo je prekidac za projekte koje ne
;; poznajes -- upalis ga rucno u baferu, i ugasis kad zavrsis.
;;
;; eglot je UGRADJEN u Emacs 30, nije paket. I nije ucitan: `eglot' je
;; autoload stub, pa dok ne otkucas M-x eglot ovaj fajl ne radi bas nista.
;; Mereno: featurep 'eglot = nil posle starta; prvi `require' kad ga
;; pozoves traje 21 ms, i placas ga samo tada.
;;
;; Ceo ovaj fajl je `with-eval-after-load' plus bindinzi, tj.
;; nula koda pri startu i nula hookova dok LSP nije upaljen.
;;
;;   C-c l l   upali LSP u ovom projektu   (M-x eglot)
;;   C-c l q   ugasi ga                    (M-x eglot-shutdown)
;;   C-c l r   preimenuj simbol svuda
;;   C-c l a   code actions (quick fix)
;;   C-c l i   implementacije interfejsa
;;   C-c l h   hover docs u prozoru (prati kursor dok je otvoren)
;;   C-c l e   lista gresaka u fajlu
;;   C-c l E   lista gresaka u celom projektu
;;   C-c l n   sledeca greska
;;   C-c l p   prethodna greska
;;
;; Kad je upaljen, radi i ono sto inace nemas: M-. skace na definiciju
;; kroz ceo projekat (tacno, ne preko regexpa kao C-c d), M-? nalazi sve
;; reference, greske se javljaju dok kucas, a company dopunjava semanticki
;; jer je company-capf vec prvi backend.

(with-eval-after-load 'eglot
  ;; eglot mapira major-mode -> server. Zna za c-mode i go-mode, ali nasi
  ;; modovi se zovu drugacije, pa ih treba dopisati.
  (add-to-list 'eglot-server-programs '(simpgo-mode . ("gopls")))
  (add-to-list 'eglot-server-programs '(simpc-mode  . ("clangd")))
  ;; eglot bi serveru poslao languageId "simpodin" (ime moda bez -mode),
  ;; a ols ocekuje "odin" -- zato se navodi eksplicitno.
  (add-to-list 'eglot-server-programs
               '((simpodin-mode :language-id "odin") . ("ols")))

  ;; Default loguje SVAKU JSON poruku izmedju Emacsa i servera u bafer od
  ;; 2 MB. Korisno za debug samog eglota, cista cena inace.
  (setq eglot-events-buffer-config '(:size 0 :format full))

  ;; Kad zatvoris poslednji bafer projekta, ugasi i server. Bez ovoga
  ;; gopls (ili ols) ostane da visi u pozadini i drzi memoriju.
  (setq eglot-autoshutdown t))

;; Koren projekta eglot trazi preko project.el -- istog onog backend-a iz
;; nav-rc.el. Znaci LSP vidi isti koren iz kog `C-c c' builduje.

(global-set-key (kbd "C-c l l") #'eglot)
(global-set-key (kbd "C-c l q") #'eglot-shutdown)
(global-set-key (kbd "C-c l r") #'eglot-rename)
(global-set-key (kbd "C-c l a") #'eglot-code-actions)
(global-set-key (kbd "C-c l i") #'eglot-find-implementation)

;; eldoc vec pise potpis u echo areji dok stojis na simbolu. Ovo otvara
;; CEO doc komentar u zasebnom prozoru, koji se osvezava kako se kreces.
(global-set-key (kbd "C-c l h") #'eldoc-doc-buffer)

;; Greske iz LSP-a idu kroz flymake, ne kroz compile bafer -- zato
;; M-g n / M-g p za njih ne rade.
(global-set-key (kbd "C-c l e") #'flymake-show-buffer-diagnostics)
;; Ceo projekat -- ali samo fajlovi za koje je server poslao dijagnoze,
;; kod gopls-a obicno paketi koje si otvarao.
(global-set-key (kbd "C-c l E") #'flymake-show-project-diagnostics)
(global-set-key (kbd "C-c l n") #'flymake-goto-next-error)
(global-set-key (kbd "C-c l p") #'flymake-goto-prev-error)

(provide 'eglot-rc)
