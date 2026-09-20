================================================================================
EMACS CHEATSHEET  --  for a Vim user
================================================================================

Emacs is NOT modal. You type, text goes in.
  C-x  means Ctrl+x        M-x  means Alt+x        RET = Enter, SPC = Space
  C-x C-s  means hold Ctrl, press x, then s.

Read this file with C-c h c from anywhere.  q closes it.


--------------------------------------------------------------------------------
THREE THINGS FOR DAY ONE
--------------------------------------------------------------------------------

  C-g               PANIC BUTTON. Cancels anything. This is your Esc.
  C-x C-s           save
  C-x C-c           quit (closes the frame; a daemon keeps running)

  Careful: C-z in a terminal SUSPENDS Emacs, it is not undo. Type fg to return.


--------------------------------------------------------------------------------
COMPILE WORKFLOW  --  the main thing
--------------------------------------------------------------------------------

  C-c c             compile (asks for the command, runs from project root)
  C-c r             repeat the last compile, no questions
  C-c k             kill a running compile
  M-g n             next error
  M-g p             previous error
  C-c s             rg search across the project (same machinery, M-g n works)
  C-c d             WHERE IS THIS DEFINED (greps the shape of a declaration)
  C-u C-c d         same, plus dependencies (go mod cache, /usr/include)
  C-c D             go doc for the symbol under the cursor

  Full writeup: COMPILE.md  (C-c h k)


--------------------------------------------------------------------------------
CONFIG DOCS  --  from inside any project
--------------------------------------------------------------------------------

  C-c h c           this cheatsheet
  C-c h k           COMPILE.md
  C-c h r           README.md
  C-c h i           open init.el for editing

  They open in view-mode: q quits, SPC and DEL scroll.
  Press C-c h and wait -- which-key lists what can follow.


================================================================================
MOVING AROUND CODE AND PROJECTS
================================================================================

--------------------------------------------------------------------------------
SPLITTING THE SCREEN
--------------------------------------------------------------------------------

Emacs calls these WINDOWS. What your OS calls a window, Emacs calls a FRAME.
Buffers and windows are separate: the same buffer can sit in two windows, and
closing a window does NOT close the buffer.

  C-x 2             split horizontally, new one below      (Vim :sp)
  C-x 3             split vertically, new one to the right (Vim :vs)
  C-x o             go to the other window  (o = other)
  S-<arrows>        go to the window in that direction
  C-x 0             close THIS window
  C-x 1             close ALL OTHER windows                (Vim :only)
  C-x ^             taller       C-x }  wider       C-x {  narrower
  C-x +             balance all windows
  C-c <left>        UNDO the window layout (winner-undo)
  C-c <right>       redo it (winner-redo)

Open something straight into the other window -- the C-x 4 prefix. Saves you
from C-x 3 followed by C-x o:

  C-x 4 f           find file in the other window
  C-x 4 b           switch buffer in the other window
  C-x 4 d           dired in the other window
  C-x 4 0           close the window AND kill the buffer in it

  The same with C-x 5 instead of C-x 4 does it in a new frame.


--------------------------------------------------------------------------------
JUMP BACK
--------------------------------------------------------------------------------

This is Vim's C-o. Emacs SETS A MARK AUTOMATICALLY before every big jump --
M-<, M->, M-g g, isearch, imenu, C-c d -- so there is always somewhere to go
back to.

  C-x C-SPC         BACK to the previous spot, across buffers too   <-- main one
  C-u C-SPC         back, but only within this buffer
  C-SPC C-SPC       set a mark by hand (before you wander off)
  C-x C-x           jump to the mark and back (exchange point and mark)

Press repeatedly to go further back. The ring wraps around: after the oldest
entry you land on the newest again.

IN A TERMINAL C-SPC often never reaches Emacs. Use C-@ or C-x C-@ instead.
Check with C-h k followed by the keys.

  C-x <left>        previous buffer   (Vim :bp)
  C-x <right>       next buffer       (Vim :bn)
  C-x b RET         back to the LAST buffer (it is the default offer)


--------------------------------------------------------------------------------
SCROLLING AND SCREEN POSITION
--------------------------------------------------------------------------------

  C-v / M-v         page down / up            (Vim C-f / C-b)
  C-l               zz / zt / zb in ONE key -- press again to cycle:
                    center, then top, then bottom
  C-u 0 C-l         redraw with point staying where it is
  M-r               H / M / L -- move point to top, middle, bottom of window
                    (press again to cycle)
  C-M-l             reposition the current function so its start is visible

  Moving off screen with the arrows scrolls line by line, not in half-screen
  jumps, and point keeps 3 lines of context above and below.

  C-v / M-v and PageUp / PageDown always jump a full page -- that is what they
  are. 5 lines of the old screen stay visible so you can tell where you landed.

  The mouse wheel scrolls 3 lines per notch (Shift: 1 line, Ctrl: text size).
  Emacs owns the mouse in the terminal, so hold Shift while dragging if you
  want your terminal's own selection instead.


--------------------------------------------------------------------------------
INSIDE ONE FILE
--------------------------------------------------------------------------------

  C-c i m           IMENU -- list of functions, pick one and jump
                    (no LSP here, this is your main navigation)
  C-c d             where the symbol is DEFINED (rg on declaration shapes)
  C-u C-c d         same, plus dependencies
  M-g g 42          go to line 42
  C-s               isearch forward (C-s again = next, RET stays there)
  C-r               isearch backward
  C-M-s             isearch by regexp
  C-M-a             beginning of function      C-M-e  end of function
  M-{               paragraph/block up         M-}    down
  C-M-f             over balanced parens       C-M-b  back  (Vim %)

Relative line numbers are on, so M-5 C-n goes 5 lines down.


--------------------------------------------------------------------------------
ACROSS THE PROJECT
--------------------------------------------------------------------------------

The project root is the nearest directory upward containing Makefile, go.mod,
build.sh or .git -- the SAME root C-c c builds from.

  C-x p f           FIND FILE IN PROJECT (type fragments, orderless handles it)
  C-x p b           switch to a buffer belonging to this project
  C-x p p           switch to ANOTHER project
  C-x p d           dired at the project root
  C-x p k           kill all buffers of this project
  C-c s             rg across the project -- results behave like compiler errors
  M-g n / M-g p     next / previous result (same keys as for errors)

  The file list comes from rg --files, so .gitignore is respected and build
  artifacts are never offered.

  C-x C-f           find file by path (typing ~/ or / mid-path resets it)
  M-p in C-x C-f    previous paths you typed (kept across sessions)
  C-x C-g           open the file whose path is under the cursor
                    (works on #include "foo.h")
  C-x d             dired -- inside: RET enter, ^ up, g refresh, q quit


--------------------------------------------------------------------------------
BOOKMARKS  --  positions that survive a restart
--------------------------------------------------------------------------------

For places you come back to for days (the main loop, a TODO in the code):

  C-x r m           remember this spot under a name
  C-x r b           jump to a remembered spot
  C-x r l           list them all (d marks for deletion, x executes, RET jumps)

For places you return to within the next few minutes -- REGISTERS, no name,
nothing written to disk:

  C-x r SPC a       store the position in register a
  C-x r j a         jump to register a


--------------------------------------------------------------------------------
LSP, ONLY WHEN YOU ASK FOR IT
--------------------------------------------------------------------------------

Off by default. eglot is built into Emacs 30 and is not even loaded until you
run it, so it costs nothing while you do not use it. Turn it on per project,
in a buffer, when you land in code you do not know.

  C-c l l           turn LSP on here        (gopls for Go, clangd for C)
  C-c l q           turn it off, the server process dies with it
  C-c l r           rename the symbol everywhere
  C-c l a           code actions / quick fix

While it is on you also get, in place of the regexp tricks:

  M-.               jump to the definition, precisely   (vs C-c d, which greps)
  M-,               jump back
  M-?               find every reference
  C-h .             show the docs for the thing under point
  M-g n / M-g p     walk the diagnostics, same keys as compiler errors

  Completion becomes semantic on its own -- company-capf is already the first
  backend, so the same TAB works, it just gets better answers.

  clangd wants a compile_commands.json in the project root; gopls only needs
  go.mod. Without those the server starts but knows very little.


================================================================================
VIM -> EMACS
================================================================================

--------------------------------------------------------------------------------
FILES
--------------------------------------------------------------------------------

  :w                C-x C-s           save
  :q                C-x C-c           quit
  :e file           C-x C-f           open (type part of the name)
  :ls               C-x b             switch buffer
  :bd               C-x k             kill buffer
  gf                C-x C-g           open file under cursor


--------------------------------------------------------------------------------
MOTION
--------------------------------------------------------------------------------

  h j k l           arrows work       or C-b C-n C-p C-f
  w / b             M-f / M-b         word forward / back
  0 / $             C-a / C-e         start / end of line
  gg / G            M-< / M->         start / end of file
  C-d / C-u         C-v / M-v         page down / up
  :42               M-g g 42          go to line
  ]]                C-c i m           imenu -- jump to a function


--------------------------------------------------------------------------------
EDITING
--------------------------------------------------------------------------------

  u                 C-/               undo
  C-r               C-g then C-/      redo (see the note below)
  D                 C-k               kill to end of line
  yy p              C-,               DUPLICATE LINE
  ddp               M-n / M-p         MOVE LINE down / up
  p                 C-y               paste (yank)
  dw                M-d               kill word


--------------------------------------------------------------------------------
INSERTING AND OPENING LINES
--------------------------------------------------------------------------------

  i                 just type          Emacs is always in insert mode
  a                 C-f then type      one char right
  A                 C-e then type      end of line
  I                 M-m then type      first non-blank char of the line
  o                 C-e RET            open a line below
  O                 C-a C-o            open a line above (C-o = open-line)
  x                 C-d                delete char forward
  X                 DEL                delete char backward
  J                 M-^                join this line to the one above
  cw                M-d then type      change word
  cc                C-a C-k then type  change whole line
  ZZ                C-x C-c            save and quit


--------------------------------------------------------------------------------
SELECTION  (Vim visual mode)
--------------------------------------------------------------------------------

There is no separate visual mode. C-SPC drops the MARK; the text between the
mark and point is the REGION, and it stays highlighted while you move.

  v                 C-SPC              start selecting
  V                 C-a C-SPC C-n      whole line
  C-v (block)       C-x SPC            rectangle-mark-mode -- true block select
  gv                C-x C-x            bring back the last region
  o (in visual)     C-x C-x            jump to the other end of the region
  ggVG              C-x h              select the whole buffer
  y                 M-w                copy
  d / x             C-w                cut
  p                 C-y                paste
  >                 C-x TAB            then arrows: shift the region sideways
  =                 C-M-\              re-indent the region
  gu / gU           C-x C-l / C-x C-u  lowercase / uppercase the region
                                       (Emacs asks to confirm the first time,
                                       these are 'disabled' commands -- say y)

Emacs also marks things by syntax, which is the closest thing to text objects:

  iw                M-@                mark the word ahead
  i(  i[  i{        C-M-SPC            mark the balanced expression ahead
  ip                M-h                mark the paragraph
  (function)        C-M-h              mark the whole function


--------------------------------------------------------------------------------
BLOCK / RECTANGLE EDITING  (Vim C-v)
--------------------------------------------------------------------------------

Select a rectangle with C-x SPC and the arrows, then:

  C-x r t           type text into every line of the rectangle (Vim I ... Esc)
  C-x r k           kill the rectangle
  C-x r y           yank it back
  C-x r d           delete it without copying
  C-x r o           push the rectangle aside, inserting blanks
  C-x r N           number the lines of the rectangle

Or use multiple cursors (C-c C-<) -- often easier than rectangles.


--------------------------------------------------------------------------------
SEARCH AND REPLACE
--------------------------------------------------------------------------------

  /                 C-s                search forward, incrementally
  ?                 C-r                search backward
  n / N             C-s C-s / C-r C-r  next / previous hit
  *                 M-s .              search the symbol under the cursor
  :noh              C-g                clear the highlight
  :%s/a/b/g         M-%                replace, asking (y / n / ! for all)
  :%s/re/b/g        C-M-%              replace by regexp
  :g/pat/d          M-x flush-lines    delete every line matching a regexp
  :v/pat/d          M-x keep-lines     keep ONLY lines matching a regexp
  :sort             M-x sort-lines     sort the lines of the region
  :grep             C-c s              rg across the project

Inside an incremental search:
  C-w               pull the next word from the buffer into the search
  C-s / C-r         next / previous hit, and switch direction
  RET               stop here          C-g   go back where you started
  M-%               start replacing what you just searched for


--------------------------------------------------------------------------------
COUNTS AND REPEATING
--------------------------------------------------------------------------------

  5j                M-5 C-n            or C-u 5 C-n
  10x               M-1 M-0 C-d        digits chain
  .                 C-x z              repeat the last command
                                       (then just press z to repeat again)
  qa ... q          F3 ... F4          record a macro
  @a                F4                 run it
  10@a              C-u 10 F4          run it 10 times
  @@                C-x e              run the last macro, e repeats


--------------------------------------------------------------------------------
THE KILL RING  (Vim registers, but automatic)
--------------------------------------------------------------------------------

Every cut and copy is pushed on a stack. This is the feature Vim users miss
most often once they know it.

  p                 C-y                paste the newest
  "1p "2p ...       C-y then M-y       paste, then cycle back through older
                                       entries -- keep pressing M-y
  "ay               C-x r s a          copy the region into register a
  "ap               C-x r i a          insert register a

Whole lines:
  dd                C-a C-k C-k        kill the whole line, newline included
                                       (C-S-DEL does the same, GUI only)
  yy                C-a C-SPC C-n M-w  copy the whole line
  yyp               C-,                duplicate the line (our binding)
  ddp / ddkP        M-n / M-p          move the line down / up


--------------------------------------------------------------------------------
FILES, BUFFERS, WINDOWS  (the ex commands)
--------------------------------------------------------------------------------

  :w file           C-x C-w            write to another name
  :e!               M-x revert-buffer  throw away edits, reread from disk
  :r file           C-x i              insert a file at point
  :sp file          C-x 4 f            open a file in a split
  :bn / :bp         C-x <right> / <left>
  :tabnew           C-x t 2            new tab (C-x t o next, C-x t 0 close)
  :make             C-c c              compile
  :cn / :cp         M-g n / M-g p      next / previous error
  C-]               C-c d              jump to a definition
  C-o               C-x C-SPC          jump back where you came from
  ga                C-x =              what character is this?
  gq                M-q                reflow the paragraph
                    C-c M-q            the opposite: join it into one line


--------------------------------------------------------------------------------
MULTIPLE CURSORS  (no Vim equivalent)
--------------------------------------------------------------------------------

  C->               next occurrence of the word under the cursor
  C-<               previous one
  C-c C-<           all occurrences at once
  C-S-c C-S-c       one cursor on every line of the selection


--------------------------------------------------------------------------------
GIT  (magit)
--------------------------------------------------------------------------------

  C-c m s           status
  C-c m l           log

  Inside the status buffer:
    s   stage               u   unstage
    c c commit, then C-c C-c to confirm
    P p push                F p pull
    ?   help                q   quit


================================================================================
WHEN YOU GET STUCK
================================================================================

  C-g               cancel
  M-x               run a command by name -- type fragments in any order,
                    the shortcut is printed on the right
  C-h k <key>       "what does this key do?"
  C-h t             the official tutorial, 20 minutes


--------------------------------------------------------------------------------
UNDO / REDO
--------------------------------------------------------------------------------

Emacs has no redo pointer. UNDO IS ITSELF AN EDIT, recorded in the history.

  C-/  C-_  C-x u        undo
  C-?  C-M-_             real redo (C-? often does not work in a terminal)

  REDO WITHOUT A SHORTCUT: press C-g (breaks the undo run), then C-/ -- now
  undo is undoing your undos, which is redo.

Better than Vim: nothing is ever thrown away, there is no lost redo branch.
Confusing: moving the cursor mid-undo breaks the run.


--------------------------------------------------------------------------------
AUTOCOMPLETE
--------------------------------------------------------------------------------

Company pops up after 2 characters. It is NOT semantic -- it offers words that
already exist in open buffers.

  TAB or RET        accept
  C-n / C-p         pick
  C-g               dismiss
