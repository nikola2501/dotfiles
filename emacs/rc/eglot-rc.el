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
;; Ceo ovaj fajl je `with-eval-after-load' plus cetiri bindinga, tj.
;; nula koda pri startu i nula hookova dok LSP nije upaljen.
;;
;;   C-c l l   upali LSP u ovom projektu   (M-x eglot)
;;   C-c l q   ugasi ga                    (M-x eglot-shutdown)
;;   C-c l r   preimenuj simbol svuda
;;   C-c l a   code actions (quick fix)
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

  ;; Default loguje SVAKU JSON poruku izmedju Emacsa i servera u bafer od
  ;; 2 MB. Korisno za debug samog eglota, cista cena inace.
  (setq eglot-events-buffer-config '(:size 0 :format full))

  ;; Kad zatvoris poslednji bafer projekta, ugasi i server. Bez ovoga
  ;; gopls ostane da visi u pozadini i drzi memoriju.
  (setq eglot-autoshutdown t))

;; Koren projekta eglot trazi preko project.el -- istog onog backend-a iz
;; nav-rc.el. Znaci LSP vidi isti koren iz kog `C-c c' builduje.

(global-set-key (kbd "C-c l l") #'eglot)
(global-set-key (kbd "C-c l q") #'eglot-shutdown)
(global-set-key (kbd "C-c l r") #'eglot-rename)
(global-set-key (kbd "C-c l a") #'eglot-code-actions)

(provide 'eglot-rc)
