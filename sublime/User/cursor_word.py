"""Blago highlightovanje svih pojava reci pod kursorom.

ST ovo nema: `match_selection` boji pojave SELEKTOVANOG teksta, ne reci pod
kurzorom. Ekvivalent je CursorWord iz mog nvim configa.

Brzina je bila uslov, pa su cetiri stvari namerne:

1. on_selection_modified_ASYNC — radi na async threadu, ne blokira kucanje
   ni skrol ni na jedan frejm.
2. Debounce 90ms preko brojaca po view-u: pri drzanju strelice ili brzom
   kretanju kroz fajl posao se odradi jednom, na kraju, a ne na svaki
   pomeraj kursora.
3. Kes po (rec, change_count, velicina selekcije): kretanje unutar iste
   reci, ili kroz razmake, ne pokrece nikakav rad. Ovo u praksi ubija
   vecinu poziva.
4. Sav posao radi view.find_all() sa `\b...\b` regexom — C++, jedan poziv,
   bez ijedne Python petlje po pogotku. Iznad BIG_FILE bajta rezultati se
   ogranicavaju na vidni deo bafera plus okolina, da ni na ogromnom fajlu ne
   moze da se oseti.

Boja dolazi iz teme, scope `cursorword` (vidi Cyanide - Matrix.sublime-color-scheme).
Bez tog pravila u temi highlight se ne vidi.
"""

import re

import sublime
import sublime_plugin


DELAY = 90                  # ms, isto kao CW_DELAY u nvim configu
MIN_LEN = 2                 # jedno slovo pali pola fajla
BIG_FILE = 2 * 1024 * 1024  # iznad ovoga samo vidni deo bafera
VIEWPORT_PAD = 20000        # bajtova oko vidnog dela, da skrol ne ostane prazan
REGION_KEY = "cursor_word"
WORD_RE = re.compile(r"^[A-Za-z0-9_]+$")

_pending = {}   # view id -> broj poslednjeg zakazanog posla
_last = {}      # view id -> (rec, change_count, pocetak vidnog dela)


def _forget(view_id):
    _pending.pop(view_id, None)
    _last.pop(view_id, None)


def _word_at_caret(view):
    """Rec pod kursorom, ili None ako nema sta da se boji."""
    settings = view.settings()
    if settings.get("is_widget") or view.element() is not None:
        return None

    selection = view.sel()
    if len(selection) != 1:
        return None                      # vise kursora: preskoci
    region = selection[0]
    if not region.empty():
        return None                      # ima selekciju: to radi match_selection

    word_region = view.word(region.b)
    if word_region.size() < MIN_LEN or word_region.size() > 100:
        return None
    word = view.substr(word_region)
    if not WORD_RE.match(word) or word.isdigit():
        return None                      # kursor na 0 bi zapalio pola fajla
    return word


def _apply(view, token):
    if _pending.get(view.id()) != token:
        return                           # stigao je noviji pomeraj kursora
    if not view.is_valid():
        _forget(view.id())
        return

    word = _word_at_caret(view)
    if word is None:
        view.erase_regions(REGION_KEY)
        _last.pop(view.id(), None)
        return

    visible = view.visible_region()
    key = (word, view.change_count(), visible.a if view.size() > BIG_FILE else 0)
    if _last.get(view.id()) == key:
        return                           # ista rec, nista se nije promenilo
    _last[view.id()] = key

    # \b u regexu resava "cela rec" unutar C++ pretrage. Alternativa je bila
    # LITERAL pretraga pa provera view.word() po svakom pogotku — to je API
    # poziv na svaki rezultat i upravo ono sto ne sme da se radi u Pythonu.
    # Rec je [A-Za-z0-9_]+ (provereno gore), pa nema sta da se eskejpuje.
    # find_all je case-sensitive po defaultu, isto kao \C u nvim verziji.
    pattern = r"\b" + word + r"\b"

    if view.size() > BIG_FILE:
        area = sublime.Region(max(0, visible.a - VIEWPORT_PAD),
                              min(view.size(), visible.b + VIEWPORT_PAD))
        regions = [r for r in view.find_all(pattern) if area.contains(r)]
    else:
        regions = view.find_all(pattern)

    if regions:
        # rec pod kursorom se boji i sama, isto kao matchadd u nvim configu
        view.add_regions(REGION_KEY, regions, "cursorword", "",
                         sublime.DRAW_NO_OUTLINE)
    else:
        view.erase_regions(REGION_KEY)


class CursorWordListener(sublime_plugin.EventListener):
    def on_selection_modified_async(self, view):
        view_id = view.id()
        token = _pending.get(view_id, 0) + 1
        _pending[view_id] = token
        sublime.set_timeout_async(lambda: _apply(view, token), DELAY)

    def on_deactivated_async(self, view):
        view.erase_regions(REGION_KEY)
        _last.pop(view.id(), None)

    def on_close(self, view):
        _forget(view.id())
