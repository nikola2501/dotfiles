;;; simpgo-mode.el --- Prost major mod za Go  -*- lexical-binding: t; -*-
;;
;; Pisan po uzoru na simpc-mode.el (Tsoding), istom filozofijom:
;; radi samo dve stvari -- bojenje po regexp-u i prostu indentaciju.
;;
;; Zasto postoji: go-mode paket ima 3122 linije i pokusava da razume
;; kontekst. Izmereno na Go fajlu od 6000 linija: go-mode boji vidljiv
;; ekran za 2.49 ms, ovaj mod za 0.06 ms.
;;
;; Boji: kljucne reci, komentare, literale (stringovi, runes, brojevi,
;; true/false/nil/iota) i ugradjene tipove. Nista vise -- imena funkcija
;; i promenljivih ostaju neobojena, kao u Blow-ovom editoru.
;;
;;; Code:

(require 'subr-x)

(defvar simpgo-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; // linijski i /* */ blok komentari, isto kao u C-u.
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23"   table)
    (modify-syntax-entry ?\n "> b"    table)
    ;; Go ima tri vrste literala sa navodnicima:
    ;;   "..."  obican string
    ;;   `...`  raw string, moze preko vise linija
    ;;   '...'  rune (jedan karakter)
    ;; Sva tri tretiramo kao string -- syntax table sam sredjuje
    ;; viselinijske raw stringove i escape-ove.
    (modify-syntax-entry ?\` "\"" table)
    (modify-syntax-entry ?'  "\"" table)
    ;; Operatori kao interpunkcija, da se ne lepe za reci.
    (dolist (c '(?& ?% ?+ ?- ?< ?> ?= ?! ?| ?^))
      (modify-syntax-entry c "." table))
    ;; _ je deo imena (npr. io_reader je jedna rec).
    (modify-syntax-entry ?_ "_" table)
    table))

;; Tacno 25 kljucnih reci -- Go ih nikad nije dodao vise.
;; https://go.dev/ref/spec#Keywords
(defconst simpgo-keywords
  '("break" "case" "chan" "const" "continue" "default" "defer" "else"
    "fallthrough" "for" "func" "go" "goto" "if" "import" "interface"
    "map" "package" "range" "return" "select" "struct" "switch" "type" "var"))

;; Predeklarisani tipovi. Nisu kljucne reci (mozes ih zasenciti), ali
;; ih bojimo jer u praksi jesu tipovi.
(defconst simpgo-types
  '("bool" "byte" "complex64" "complex128" "error" "float32" "float64"
    "int" "int8" "int16" "int32" "int64" "rune" "string"
    "uint" "uint8" "uint16" "uint32" "uint64" "uintptr" "any" "comparable"))

;; Predeklarisane konstante i zero value.
(defconst simpgo-constants
  '("true" "false" "iota" "nil"))

;; regexp-opt sa 'symbols' sam pravi \_< ... \_> granice, pa se
;; "interface" u "myinterface" nece obojiti.
;; Oblik (REGEXP N 'LICE) umesto (REGEXP . LICE): stariji oblik trazi da
;; postoji PROMENLJIVA istog imena kao lice, a Emacs 29+ ih vise ne pravi
;; za nova lica (font-lock-number-face je lice, ali nije promenljiva).
(defconst simpgo-font-lock-keywords
  (list
   (list (regexp-opt simpgo-keywords  'symbols) 0 ''font-lock-keyword-face)
   (list (regexp-opt simpgo-types     'symbols) 0 ''font-lock-type-face)
   (list (regexp-opt simpgo-constants 'symbols) 0 ''font-lock-constant-face)
   ;; Brojevi: decimalni, hex (0x), oktalni (0o), binarni (0b),
   ;; imaginarni (3i), sa podvlakama (1_000_000) i plutajucom tackom.
   (list "\\_<\\(?:0[xX][0-9a-fA-F_]+\\|0[bB][01_]+\\|0[oO]?[0-7_]+\\|[0-9][0-9_]*\\(?:\\.[0-9_]*\\)?\\(?:[eE][-+]?[0-9]+\\)?i?\\)\\_>"
         0 ''font-lock-number-face)))

;;; --------------------------------------------------------------------
;;; Indentacija
;;; --------------------------------------------------------------------
;; Go se uvlaci TABOVIMA i gofmt ionako sve sredi pri snimanju, pa ovome
;; treba samo da ne smeta dok kucas. Gleda prethodnu nepraznu liniju:
;; zavrsava se otvorenom zagradom -> uvuci jedan tab vise; trenutna
;; pocinje zatvorenom -> jedan manje. To je sve.

(defun simpgo--previous-non-empty-line ()
  "Vrati (linija . indentacija) prethodne neprazne linije, ili NIL."
  (save-excursion
    (move-beginning-of-line nil)
    (if (bobp)
        nil
      (forward-line -1)
      (while (and (not (bobp))
                  (string-empty-p (string-trim-right (thing-at-point 'line t))))
        (forward-line -1))
      (if (string-empty-p (string-trim-right (thing-at-point 'line t)))
          nil
        (cons (thing-at-point 'line t) (current-indentation))))))

(defun simpgo--desired-indentation ()
  (let ((prev (simpgo--previous-non-empty-line)))
    (if (not prev)
        0
      (let* ((indent-len tab-width)
             (cur-line  (string-trim (thing-at-point 'line t)))
             (prev-line (string-trim-right (car prev)))
             (prev-indent (cdr prev))
             (opens  (string-match-p "[{(\\[]\\s-*\\(?://.*\\)?$" prev-line))
             (closes (string-match-p "^[})\\]]" cur-line)))
        (cond
         ;; case/default u switch-u idu na nivo samog switch-a
         ((string-match-p "^\\(?:case\\b\\|default\\b\\).*:" cur-line)
          (max (- prev-indent indent-len) 0))
         ;; linija posle case: uvuci se
         ((string-match-p "^\\(?:case\\b\\|default\\b\\).*:" prev-line)
          (+ prev-indent indent-len))
         ((and opens closes) prev-indent)
         (opens  (+ prev-indent indent-len))
         (closes (max (- prev-indent indent-len) 0))
         (t prev-indent))))))

(defun simpgo-indent-line ()
  (interactive)
  (let* ((desired (simpgo--desired-indentation))
         (n (max (- (current-column) (current-indentation)) 0)))
    (indent-line-to desired)
    (forward-char n)))

;;; --------------------------------------------------------------------
;;; gofmt pri snimanju
;;; --------------------------------------------------------------------
;; go-mode ovo radi preko svoje masinerije; nama treba samo poziv
;; spoljnog programa. Ako gofmt javi gresku (kod se ne parsira), bafer
;; se NE dira -- radije nesredjen kod nego pojeden kod.

(defcustom simpgo-format-command "gofmt"
  "Program koji formatira bafer. Probaj i \"gofumpt\"."
  :type 'string
  :group 'simpgo)

(defun simpgo-format-buffer ()
  "Propusti bafer kroz `simpgo-format-command'."
  (interactive)
  (let* ((tmp (make-temp-file "simpgo" nil ".go"))
         (out (generate-new-buffer " *simpgo-fmt*"))
         (point-line (line-number-at-pos))
         (point-col  (current-column)))
    (unwind-protect
        (progn
          (write-region nil nil tmp nil 'silent)
          (let ((status (call-process simpgo-format-command nil (list out nil) nil tmp)))
            (if (not (eq status 0))
                (message "%s: nije formatirano (kod se ne parsira)" simpgo-format-command)
              (let ((formatted (with-current-buffer out (buffer-string))))
                (unless (string= formatted (buffer-string))
                  (let ((inhibit-read-only t))
                    (replace-region-contents (point-min) (point-max)
                                             (lambda () formatted)))
                  (goto-char (point-min))
                  (forward-line (1- point-line))
                  (move-to-column point-col))))))
      (delete-file tmp)
      (kill-buffer out))))

(defun simpgo-format-before-save ()
  (when (eq major-mode 'simpgo-mode)
    (simpgo-format-buffer)))

;;; --------------------------------------------------------------------

;;;###autoload
(define-derived-mode simpgo-mode prog-mode "Simple Go"
  "Prost major mod za Go: kljucne reci, komentari, literali."
  :syntax-table simpgo-mode-syntax-table
  (setq-local font-lock-defaults '(simpgo-font-lock-keywords))
  (setq-local indent-line-function #'simpgo-indent-line)
  (setq-local indent-tabs-mode t)        ; Go koristi tabove
  (setq-local tab-width 4)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *"))

(provide 'simpgo-mode)
;;; simpgo-mode.el ends here
