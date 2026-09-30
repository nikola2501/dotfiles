;;; matrix-theme.el --- Port moje Sublime teme "Cyanide - Matrix"  -*- lexical-binding: t; -*-
;;
;; Izvor boja, istim redom kao u nvim portu:
;;   sublime/User/Cyanide - Matrix.sublime-color-scheme   (mesto istine)
;;   ~/.config/nvim/lua/matrix/palette.lua                (isti set, za TUI)
;; Ako menjam boju tamo, menjam je i ovde.
;;
;; Mapiranje Sublime scope -> Emacs lice:
;;   keyword, storage                    -> green     font-lock-keyword-face
;;   constant.numeric/language           -> green     number/constant-face
;;   string, constant.character          -> blue      font-lock-string-face
;;   constant.character.escape           -> green b.  font-lock-escape-face
;;   comment                             -> comment   font-lock-comment-face
;;   entity.name.function, function-call -> fg_func
;;   entity.name.class, support.type     -> fg_type   font-lock-type-face
;;   keyword.operator, punctuation       -> fg_op
;;   variable                            -> fg
;;
;; simpgo/simpc/simpodin boje samo keyword, type, constant, number, string i
;; comment. Ostala lica su tu za magit, flymake, company, vertico, dired.

(deftheme matrix
  "Port Sublime teme Cyanide - Matrix: neon zeleno na skoro crnom.")

(let* ((bg         "#0a0a0a")
       (fg         "#cccccc")
       (fg-type    "#dddddd")
       (fg-func    "#efefef")
       (fg-op      "#aaaaaa")
       (invisibles "#6a6a6a")

       ;; neon set: sat 100% / val 100%
       (green      "#00ff41")
       (blue       "#00bfff")
       (comment    "#ff0055")
       (bracket    "#ff0055")
       (caret      "#39ff14")
       (warn       "#ffdd00")
       (err        "#ff2200")
       (cyan       "#00d4ff")

       ;; UI slojevi, podignuti kao u Sublime override-u i nvim-u
       (gutter     "#707070")
       (cursorline "#1c1c1c")
       (selection  "#333333")
       (guide      "#2a2a2a")
       (float-bg   "#121212")         ; .sublime-theme layer0.tint [18,18,18]
       (separator  "#1f7a35")         ; nvim WinSeparator
       (cursorword "#404040")         ; cursor_word.py / nvim CursorWord

       ;; diff pozadine iz nvim palette.lua -- tema daje samo fg
       (diff-add-bg "#0d2a10")
       (diff-del-bg "#2a0d0d")
       (diff-chg-bg "#0d1a2a"))

  (custom-theme-set-faces
   'matrix

   ;; --- Osnova ----------------------------------------------------------
   `(default ((t (:foreground ,fg :background ,bg))))
   `(cursor ((t (:background ,caret))))
   `(fringe ((t (:background ,bg))))
   ;; Selekcija plava. Tekst u njoj je UVEK tamni bg, a ne boja sintakse:
   ;; zeleno ili crveno na plavom bi bilo necitljivo. #0a0a0a na #00bfff
   ;; je 9.3:1 (WCAG AAA je 7:1).
   `(region ((t (:foreground ,bg :background ,blue :extend t))))
   `(secondary-selection ((t (:background ,cursorline))))
   `(hl-line ((t (:background ,cursorline))))
   `(highlight ((t (:background ,selection))))
   `(shadow ((t (:foreground ,gutter))))
   `(minibuffer-prompt ((t (:foreground ,green :weight bold))))
   `(link ((t (:foreground ,blue :underline t))))
   `(link-visited ((t (:foreground ,blue :underline t))))
   `(error ((t (:foreground ,err :weight bold))))
   `(warning ((t (:foreground ,warn))))
   `(success ((t (:foreground ,green))))
   `(escape-glyph ((t (:foreground ,green))))
   `(homoglyph ((t (:foreground ,green))))
   `(trailing-whitespace ((t (:background ,err))))
   `(vertical-border ((t (:foreground ,separator))))
   `(window-divider ((t (:foreground ,separator))))
   `(header-line ((t (:foreground ,fg :background ,float-bg))))
   `(tooltip ((t (:foreground ,fg :background ,float-bg))))

   ;; Brojevi linija: gutter #707070, trenutna linija zelena kao u nvim-u
   `(line-number ((t (:foreground ,gutter :background ,bg))))
   `(line-number-current-line ((t (:foreground ,green :background ,bg :weight bold))))

   ;; Mode line = nvim StatusLine / StatusLineNC
   `(mode-line ((t (:foreground ,fg :background ,float-bg :box (:line-width 1 :color ,separator)))))
   `(mode-line-inactive ((t (:foreground ,fg-op :background ,bg :box (:line-width 1 :color ,guide)))))
   `(mode-line-buffer-id ((t (:foreground ,green :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,green :weight bold))))
   `(mode-line-highlight ((t (:box (:line-width 1 :color ,green)))))

   ;; --- Sintaksa --------------------------------------------------------
   `(font-lock-comment-face ((t (:foreground ,comment))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,comment))))
   `(font-lock-doc-face ((t (:foreground ,comment))))
   `(font-lock-doc-markup-face ((t (:foreground ,comment :weight bold))))
   `(font-lock-string-face ((t (:foreground ,blue))))
   `(font-lock-escape-face ((t (:foreground ,green :weight bold))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,green :weight bold))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,green :weight bold))))
   `(font-lock-keyword-face ((t (:foreground ,green))))
   `(font-lock-builtin-face ((t (:foreground ,green))))
   `(font-lock-preprocessor-face ((t (:foreground ,green))))
   `(font-lock-constant-face ((t (:foreground ,green))))
   `(font-lock-number-face ((t (:foreground ,green))))
   `(font-lock-type-face ((t (:foreground ,fg-type))))
   `(font-lock-function-name-face ((t (:foreground ,fg-func))))
   `(font-lock-function-call-face ((t (:foreground ,fg-func))))
   `(font-lock-variable-name-face ((t (:foreground ,fg))))
   `(font-lock-variable-use-face ((t (:foreground ,fg))))
   `(font-lock-property-name-face ((t (:foreground ,fg))))
   `(font-lock-property-use-face ((t (:foreground ,fg))))
   `(font-lock-operator-face ((t (:foreground ,fg-op))))
   `(font-lock-punctuation-face ((t (:foreground ,fg-op))))
   `(font-lock-bracket-face ((t (:foreground ,fg-op))))
   `(font-lock-delimiter-face ((t (:foreground ,fg-op))))
   `(font-lock-misc-punctuation-face ((t (:foreground ,fg-op))))
   `(font-lock-negation-char-face ((t (:foreground ,fg-op))))
   `(font-lock-warning-face ((t (:foreground ,warn :weight bold))))

   ;; Par zagrada: brackets_foreground, "foreground bold"
   `(show-paren-match ((t (:foreground ,bracket :weight bold))))
   `(show-paren-mismatch ((t (:foreground ,bg :background ,err :weight bold))))

   ;; --- Pretraga: nvim IncSearch / Search -------------------------------
   `(isearch ((t (:foreground ,bg :background ,green :weight bold))))
   `(isearch-fail ((t (:foreground ,err :weight bold))))
   `(lazy-highlight ((t (:foreground ,bg :background ,fg-op))))
   `(match ((t (:foreground ,bg :background ,green))))
   `(query-replace ((t (:foreground ,bg :background ,green :weight bold))))

   ;; Samo trailing whitespace (vidi misc-rc.el)
   `(whitespace-trailing ((t (:background ,err))))
   `(whitespace-space ((t (:foreground ,invisibles))))
   `(whitespace-tab ((t (:foreground ,invisibles))))

   ;; --- Completion: vertico / orderless / marginalia / company ----------
   `(vertico-current ((t (:background ,selection :weight bold :extend t))))
   `(completions-common-part ((t (:foreground ,green :weight bold))))
   `(completions-first-difference ((t (:foreground ,fg-func))))
   `(orderless-match-face-0 ((t (:foreground ,green :weight bold))))
   `(orderless-match-face-1 ((t (:foreground ,blue :weight bold))))
   `(orderless-match-face-2 ((t (:foreground ,warn :weight bold))))
   `(orderless-match-face-3 ((t (:foreground ,cyan :weight bold))))
   `(marginalia-key ((t (:foreground ,green))))
   `(marginalia-documentation ((t (:foreground ,gutter))))
   `(company-tooltip ((t (:foreground ,fg :background ,float-bg))))
   `(company-tooltip-selection ((t (:background ,selection :weight bold))))
   `(company-tooltip-common ((t (:foreground ,green :weight bold))))
   `(company-tooltip-common-selection ((t (:foreground ,green :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,fg-op))))
   `(company-tooltip-scrollbar-track ((t (:background ,cursorline))))
   `(company-tooltip-scrollbar-thumb ((t (:background ,fg-op))))
   `(company-preview ((t (:foreground ,fg-op))))
   `(company-preview-common ((t (:foreground ,green))))

   ;; --- which-key -------------------------------------------------------
   `(which-key-key-face ((t (:foreground ,green :weight bold))))
   `(which-key-group-description-face ((t (:foreground ,blue))))
   `(which-key-command-description-face ((t (:foreground ,fg))))
   `(which-key-separator-face ((t (:foreground ,gutter))))

   ;; --- Dijagnoze: flymake / compile ------------------------------------
   `(flymake-error ((t (:underline (:style wave :color ,err)))))
   `(flymake-warning ((t (:underline (:style wave :color ,warn)))))
   `(flymake-note ((t (:underline (:style wave :color ,blue)))))
   `(compilation-error ((t (:foreground ,err :weight bold))))
   `(compilation-warning ((t (:foreground ,warn))))
   `(compilation-info ((t (:foreground ,blue))))
   `(compilation-line-number ((t (:foreground ,green))))
   `(compilation-column-number ((t (:foreground ,fg-op))))
   `(compilation-mode-line-exit ((t (:foreground ,green :weight bold))))
   `(compilation-mode-line-fail ((t (:foreground ,err :weight bold))))
   `(eglot-highlight-symbol-face ((t (:background ,cursorword))))

   ;; --- Diff: markup.inserted/deleted.diff, meta.diff.range -------------
   `(diff-added ((t (:foreground ,green :background ,diff-add-bg :extend t))))
   `(diff-removed ((t (:foreground ,err :background ,diff-del-bg :extend t))))
   `(diff-changed ((t (:foreground ,blue :background ,diff-chg-bg :extend t))))
   `(diff-hunk-header ((t (:foreground ,cyan :slant italic))))
   `(diff-file-header ((t (:foreground ,fg-func :weight bold))))
   `(diff-header ((t (:foreground ,fg-op))))
   `(magit-diff-added ((t (:foreground ,green :background ,diff-add-bg :extend t))))
   `(magit-diff-added-highlight ((t (:foreground ,green :background ,diff-add-bg :weight bold :extend t))))
   `(magit-diff-removed ((t (:foreground ,err :background ,diff-del-bg :extend t))))
   `(magit-diff-removed-highlight ((t (:foreground ,err :background ,diff-del-bg :weight bold :extend t))))
   `(magit-diff-context ((t (:foreground ,fg-op :extend t))))
   `(magit-diff-context-highlight ((t (:foreground ,fg :background ,cursorline :extend t))))
   `(magit-diff-hunk-heading ((t (:foreground ,cyan :background ,cursorline :slant italic :extend t))))
   `(magit-diff-hunk-heading-highlight ((t (:foreground ,cyan :background ,selection :slant italic :extend t))))
   `(magit-diff-file-heading ((t (:foreground ,fg-func :weight bold :extend t))))
   `(magit-diff-file-heading-highlight ((t (:foreground ,fg-func :background ,cursorline :weight bold :extend t))))
   `(magit-section-heading ((t (:foreground ,green :weight bold))))
   `(magit-section-highlight ((t (:background ,cursorline :extend t))))
   `(magit-branch-local ((t (:foreground ,green))))
   `(magit-branch-remote ((t (:foreground ,blue))))
   `(magit-branch-current ((t (:foreground ,green :weight bold :box (:line-width 1 :color ,green)))))
   `(magit-hash ((t (:foreground ,gutter))))
   `(magit-tag ((t (:foreground ,warn))))
   `(magit-log-author ((t (:foreground ,fg-op))))
   `(magit-log-date ((t (:foreground ,gutter))))
   `(magit-dimmed ((t (:foreground ,gutter))))

   ;; --- dired -----------------------------------------------------------
   `(dired-directory ((t (:foreground ,green :weight bold))))
   `(dired-symlink ((t (:foreground ,cyan))))
   `(dired-header ((t (:foreground ,green :weight bold))))
   `(dired-marked ((t (:foreground ,warn :weight bold))))
   `(dired-flagged ((t (:foreground ,err :weight bold))))
   `(dired-ignored ((t (:foreground ,gutter))))

   ;; --- Markdown / org naslovi: markup.heading = green -------------------
   `(outline-1 ((t (:foreground ,green :weight bold))))
   `(outline-2 ((t (:foreground ,green))))
   `(outline-3 ((t (:foreground ,fg-func :weight bold))))
   `(outline-4 ((t (:foreground ,fg-func))))))

(provide-theme 'matrix)

;;; matrix-theme.el ends here
