;;; rc.el --- Bootstrap za pakete  -*- lexical-binding: t; -*-
;;
;; Tsoding-ov pristup: nema use-package, nema straight, nema elpaca.
;; Samo `rc/require' koji instalira paket ako fali. Sve je eksplicitno --
;; kad citas init.el vidis tacno sta se instalira i kad.

;; Korporativni TLS proxy (Netskope, Zscaler) potpisuje SVAKU https vezu svojim
;; CA sertifikatom. GnuTLS na macOS-u cita samo /etc/ssl/cert.pem, u kome tog
;; CA nema, pa skidanje paketa stane na "Continue connecting?" -- a u daemon
;; modu nema ko da odgovori, i init.el padne na prvom `rc/require'. Ako
;; masina drzi taj CA u pem fajlu, kazi to GnuTLS-u. Gde fajla nema, ovo je
;; no-op. Mora pre `package-initialize' i prvog `package-refresh-contents'.
(require 'gnutls)
(dolist (pem '("~/corporate-certs.pem"))
  (let ((f (expand-file-name pem)))
    (when (file-exists-p f)
      (add-to-list 'gnutls-trustfiles f))))

(require 'package)

(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

(package-initialize)

;; `package-refresh-contents' je spor (mrezni poziv). Zovemo ga najvise
;; jednom po sesiji, i to tek kad stvarno fali neki paket.
(defvar rc/package-contents-refreshed nil)

(defun rc/package-refresh-contents-once ()
  (unless rc/package-contents-refreshed
    (setq rc/package-contents-refreshed t)
    (package-refresh-contents)))

(defun rc/require-one-package (package)
  (unless (package-installed-p package)
    (rc/package-refresh-contents-once)
    (package-install package)))

(defun rc/require (&rest packages)
  "Instaliraj PACKAGES ako vec nisu instalirani."
  (dolist (package packages)
    (rc/require-one-package package)))

(defun rc/require-theme (theme)
  "Instaliraj <THEME>-theme paket i ucitaj THEME."
  (let ((theme-package (intern (concat (symbol-name theme) "-theme"))))
    (rc/require theme-package)
    (load-theme theme t)))

(provide 'rc)
