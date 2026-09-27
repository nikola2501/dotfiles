;;; simpodin-mode.el --- Prost major mod za Odin  -*- lexical-binding: t; -*-
;;
;; Ista filozofija kao simpc-mode.el i simpgo-mode.el: radi samo dve
;; stvari -- bojenje po regexp-u i prostu indentaciju po zagradama.
;; Nema parsiranja, nema konteksta, nema paketa sa MELPA-e.
;;
;; Boji: kljucne reci, komentare (i ugnjezdene /* /* */ */), literale,
;; ugradjene tipove, direktive (#partial, #force_inline, #load...) i
;; atribute (@(private), @export). Imena procedura i promenljivih ostaju
;; neobojena, kao u C-u i Go-u.
;;
;;; Code:

(require 'subr-x)

(defvar simpodin-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; // linijski i /* */ blok komentari. `n' na * znaci da se blok
    ;; komentari UGNJEZDJUJU -- Odin to dozvoljava, C i Go ne.
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23n"  table)
    (modify-syntax-entry ?\n "> b"    table)
    ;; "..." string, `...` raw string, '...' rune -- sve kao string.
    (modify-syntax-entry ?\` "\"" table)
    (modify-syntax-entry ?'  "\"" table)
    ;; Operatori kao interpunkcija, da se ne lepe za reci.
    ;; # (direktive), @ (atributi), $ (polimorfni parametri) takodje.
    (dolist (c '(?& ?% ?+ ?- ?< ?> ?= ?! ?| ?^ ?# ?@ ?$ ?~))
      (modify-syntax-entry c "." table))
    (modify-syntax-entry ?_ "_" table)
    table))

;; Tacno 40 kljucnih reci, prepisano iz tokenizera samog kompajlera:
;;   $(odin root)/core/odin/tokenizer/token.odin
(defconst simpodin-keywords
  '("asm" "auto_cast" "bit_field" "bit_set" "break" "case" "cast" "context"
    "continue" "defer" "distinct" "do" "dynamic" "else" "enum" "fallthrough"
    "for" "foreign" "if" "import" "in" "map" "matrix" "not_in" "or_break"
    "or_continue" "or_else" "or_return" "package" "proc" "return" "struct"
    "switch" "transmute" "typeid" "union" "using" "when" "where"))

;; Ugradjeni tipovi iz base/builtin/builtin.odin. Kao u Go-u, nisu
;; kljucne reci, ali ih bojimo jer u praksi jesu tipovi.
(defconst simpodin-types
  '("bool" "b8" "b16" "b32" "b64" "byte"
    "int" "i8" "i16" "i32" "i64" "i128"
    "uint" "u8" "u16" "u32" "u64" "u128" "uintptr"
    "i16le" "i32le" "i64le" "i128le" "u16le" "u32le" "u64le" "u128le"
    "i16be" "i32be" "i64be" "i128be" "u16be" "u32be" "u64be" "u128be"
    "f16" "f32" "f64" "f16le" "f32le" "f64le" "f16be" "f32be" "f64be"
    "complex32" "complex64" "complex128"
    "quaternion64" "quaternion128" "quaternion256"
    "rune" "string" "cstring" "rawptr" "any"))

(defconst simpodin-constants
  '("true" "false" "nil"))

;; Oblik (REGEXP N 'LICE), isto kao u simpgo-mode.el i iz istog razloga.
(defconst simpodin-font-lock-keywords
  (list
   ;; #partial switch, #force_inline, #load("x"), #assert(...)
   (list "#[A-Za-z_]+" 0 ''font-lock-preprocessor-face)
   ;; @(private), @(link_name="x"), @export
   (list "@\\(?:([^)\n]*)\\|[A-Za-z_]+\\)" 0 ''font-lock-preprocessor-face)
   (list (regexp-opt simpodin-keywords  'symbols) 0 ''font-lock-keyword-face)
   (list (regexp-opt simpodin-types     'symbols) 0 ''font-lock-type-face)
   (list (regexp-opt simpodin-constants 'symbols) 0 ''font-lock-constant-face)
   ;; --- je "neinicijalizovano": x: [64]u8 = ---
   (list "---" 0 ''font-lock-constant-face)
   ;; Brojevi: decimalni, hex (0x), hex float (0h), binarni (0b),
   ;; oktalni (0o), dozenalni (0z), podvlake, eksponent i imaginarni
   ;; sufiksi i/j/k. Tacka mora imati cifru iza sebe, da `0..<10' ne
   ;; pojede tacku iz range operatora.
   (list "\\_<\\(?:0[xXhH][0-9a-fA-F_]+\\|0[bB][01_]+\\|0[oO][0-7_]+\\|0[zZ][0-9abAB_]+\\|[0-9][0-9_]*\\(?:\\.[0-9][0-9_]*\\)?\\(?:[eE][-+]?[0-9]+\\)?[ijk]?\\)\\_>"
         0 ''font-lock-number-face)))

;;; --------------------------------------------------------------------
;;; Indentacija
;;; --------------------------------------------------------------------
;; Isto pravilo kao u simpgo-mode.el: Odin se po konvenciji (core
;; biblioteka) uvlaci TABOVIMA, a `case' stoji na nivou `switch'-a.
;; Prethodna linija se zavrsava otvorenom zagradom -> jedan tab vise;
;; trenutna pocinje zatvorenom -> jedan manje.

(defun simpodin--previous-non-empty-line ()
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

(defun simpodin--desired-indentation ()
  (let ((prev (simpodin--previous-non-empty-line)))
    (cond
     ;; Unutar /* */ komentara ili `raw` stringa je slobodan tekst (core
     ;; ima duge doc komentare sa primerima) -- ne diraj ga.
     ((nth 8 (syntax-ppss (line-beginning-position)))
      (current-indentation))
     ((not prev)
      0)
     (t
      (let* ((indent-len tab-width)
             (cur-line  (string-trim (thing-at-point 'line t)))
             (prev-line (string-trim-right (car prev)))
             (prev-indent (cdr prev))
             (opens  (string-match-p "[{(\\[]\\s-*\\(?://.*\\)?$" prev-line))
             ;; ] mora biti PRVI u [...]; "\\]" unutar klase nije escape.
             (closes (string-match-p "^[]})]" cur-line))
             (case-re "^\\s-*case\\b.*:\\s-*\\(?://.*\\)?$"))
        (cond
         ;; case ide na nivo samog switch-a. Iznad njega je ili
         ;; "switch x {" ili drugi (prazan) case -- oba na istom nivou --
         ;; ili telo prethodnog case-a, koje je tab dublje.
         ((string-match-p case-re cur-line)
          (if (or opens (string-match-p case-re prev-line))
              prev-indent
            (max (- prev-indent indent-len) 0)))
         ;; linija posle case: uvuci se, osim ako zatvara switch
         ((string-match-p case-re prev-line)
          (if closes prev-indent (+ prev-indent indent-len)))
         ((and opens closes) prev-indent)
         (opens  (+ prev-indent indent-len))
         (closes (max (- prev-indent indent-len) 0))
         (t prev-indent)))))))

(defun simpodin-indent-line ()
  (interactive)
  (let* ((desired (simpodin--desired-indentation))
         (n (max (- (current-column) (current-indentation)) 0)))
    (indent-line-to desired)
    (forward-char n)))

;;; --------------------------------------------------------------------

;;;###autoload
(define-derived-mode simpodin-mode prog-mode "Simple Odin"
  "Prost major mod za Odin: kljucne reci, komentari, literali."
  :syntax-table simpodin-mode-syntax-table
  (setq-local font-lock-defaults '(simpodin-font-lock-keywords))
  (setq-local indent-line-function #'simpodin-indent-line)
  (setq-local indent-tabs-mode t)        ; Odin core koristi tabove
  (setq-local tab-width 4)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *"))

(provide 'simpodin-mode)
;;; simpodin-mode.el ends here
