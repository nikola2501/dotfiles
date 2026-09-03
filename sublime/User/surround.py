"""Dodaj, obrisi i zameni granicnike oko teksta — port iz mog nvim configa.

Sublime ima Ctrl+Shift+K, dupliranje, multi-kursor — ali nema recenicu za
"promeni ove zagrade u one". Ovo je ta recenica, sa istom semantikom kao
sekcija SURROUND u ~/.config/nvim/init.lua, koja je i sama port
vim-surround konvencije.

    ctrl+shift+y {char}         opkoli selekciju, ili rec pod kursorom
    ctrl+shift+x {char}         obrisi okruzujuci par
    ctrl+shift+u {old}{new}     promeni jedan par u drugi

Karakter se ne kuca u Enter-om potvrdjeno polje: input panel se sam zatvori
i odradi posao kad se ukuca dovoljno znakova (jedan, odnosno dva). Time je
osecaj isti kao u vim-u, a ne trazi chord mapu za svaki od 15 karaktera.

OTVARAJUCI karakter dodaje razmak iznutra, zatvarajuci ne:

    ctrl+shift+y (   ->  ( word )
    ctrl+shift+y )   ->  (word)

`b r B a` su zatvarajuci oblici `( [ { <`, kao u vim-surround-u. Brisanje
para koji ima taj razmak brise i njega, da add i delete budu round trip.

Sve radi nad svakom selekcijom (Sublime je multi-kursor editor), a izmene
se primenjuju od kraja bafera prema pocetku, da ranije pozicije ne odu u
pogresno mesto dok se tekst pomera.
"""

import sublime
import sublime_plugin


PAIRS = {"(": ("(", ")"), "[": ("[", "]"), "{": ("{", "}"), "<": ("<", ">")}
CLOSERS = {")": "(", "]": "[", "}": "{", ">": "<",
           "b": "(", "r": "[", "B": "{", "a": "<"}
QUOTES = ("'", '"', "`")

# koliko znakova oko kursora se gleda pri trazenju para; dovoljno za svaku
# realnu funkciju, a spasava od skeniranja celog minifikovanog fajla
SCAN_LIMIT = 200000


def _wrap_with(char):
    """(levo, desno) kojim se obavija, ili None za nepoznat karakter."""
    pair = PAIRS.get(char)
    if pair:
        return pair[0] + " ", " " + pair[1]      # otvarajuci: razmak iznutra
    opener = CLOSERS.get(char)
    if opener:
        return PAIRS[opener]                     # zatvarajuci: bez razmaka
    if char in QUOTES:
        return char, char
    return None


def _delims_for(char):
    """(otvoreni, zatvoreni) granicnik koji karakter imenuje, ili None.

    x( i x) traze istu stvar, kao u nvim verziji.
    """
    if char in PAIRS:
        return PAIRS[char]
    opener = CLOSERS.get(char)
    if opener:
        return PAIRS[opener]
    if char in QUOTES:
        return char, char
    return None


def _find_bracket(view, point, open_ch, close_ch):
    """(pozicija otvorenog, pozicija zatvorenog) oko point, ili None."""
    size = view.size()
    low = max(0, point - SCAN_LIMIT)
    high = min(size, point + SCAN_LIMIT)

    # ako kursor stoji na samom granicniku, taj par se i trazi
    here = view.substr(point) if point < size else ""
    start = None
    if here == open_ch:
        start = point
    else:
        depth = 0
        i = point - 1
        if here == close_ch:
            i = point - 1
        while i >= low:
            ch = view.substr(i)
            if ch == close_ch:
                depth += 1
            elif ch == open_ch:
                if depth == 0:
                    start = i
                    break
                depth -= 1
            i -= 1
    if start is None:
        return None

    depth = 0
    j = start + 1
    while j < high:
        ch = view.substr(j)
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            if depth == 0:
                return start, j
            depth -= 1
        j += 1
    return None


def _find_quote(view, point, quote):
    """Navodnici se ne ugnjezduju, pa se trazi najblizi par u istoj liniji."""
    line = view.line(point)
    text = view.substr(line)
    offset = point - line.a

    before = text.rfind(quote, 0, offset + 1)
    if before < 0:
        return None
    after = text.find(quote, before + 1)
    if after < 0 or after < offset:
        # kursor je iza zatvarajuceg: probaj par koji pocinje ovde
        after = text.find(quote, offset)
        before = text.rfind(quote, 0, offset)
        if before < 0 or after < 0:
            return None
    return line.a + before, line.a + after


def _find_pair(view, point, char):
    delims = _delims_for(char)
    if delims is None:
        return None
    open_ch, close_ch = delims
    if open_ch == close_ch:
        return _find_quote(view, point, open_ch)
    return _find_bracket(view, point, open_ch, close_ch)


def _padding(view, open_pos, close_pos):
    """1 ako par ima razmak iznutra sa obe strane, inace 0.

    Bez ovoga `ctrl+shift+y (` pa `ctrl+shift+x (` ne bi bio round trip —
    ostala bi ` word `.
    """
    if close_pos - open_pos < 4:
        return 0
    if (view.substr(open_pos + 1) == " "
            and view.substr(close_pos - 1) == " "):
        return 1
    return 0


def _targets(view):
    """Regioni na koje se primenjuje, od kraja bafera prema pocetku."""
    regions = []
    for region in view.sel():
        if region.empty():
            regions.append(view.word(region.b))
        else:
            regions.append(region)
    return sorted(regions, key=lambda r: -r.begin())


class SurroundPromptCommand(sublime_plugin.WindowCommand):
    """Input panel koji se sam zatvori kad se ukuca dovoljno znakova."""

    caption = "surround:"
    needed = 1
    target = None

    def run(self):
        view = self.window.active_view()
        if view is None:
            return
        self.done = False
        self.window.show_input_panel(
            self.caption, "", self.on_done, self.on_change, None)

    def on_change(self, text):
        if self.done or len(text) < self.needed:
            return
        self.done = True
        self.window.run_command("hide_panel", {"cancel": True})
        view = self.window.active_view()
        if view is not None:
            view.run_command(self.target, {"chars": text[:self.needed]})

    def on_done(self, text):
        if not self.done and len(text) >= self.needed:
            self.done = True
            view = self.window.active_view()
            if view is not None:
                view.run_command(self.target, {"chars": text[:self.needed]})


class SurroundAddPromptCommand(SurroundPromptCommand):
    caption = "surround with:"
    needed = 1
    target = "surround_add"


class SurroundDeletePromptCommand(SurroundPromptCommand):
    caption = "delete surrounding:"
    needed = 1
    target = "surround_delete"


class SurroundChangePromptCommand(SurroundPromptCommand):
    caption = "change surrounding (old new):"
    needed = 2
    target = "surround_change"


class SurroundAddCommand(sublime_plugin.TextCommand):
    def run(self, edit, chars):
        wrap = _wrap_with(chars[0])
        if wrap is None:
            self.view.window().status_message(
                "surround: ne znam par za '{}'".format(chars[0]))
            return
        left, right = wrap
        for region in _targets(self.view):
            if region.empty():
                continue
            self.view.insert(edit, region.end(), right)
            self.view.insert(edit, region.begin(), left)


class SurroundDeleteCommand(sublime_plugin.TextCommand):
    def run(self, edit, chars):
        view = self.view
        found = []
        for region in view.sel():
            pair = _find_pair(view, region.b, chars[0])
            if pair:
                found.append(pair)
        if not found:
            view.window().status_message(
                "surround: nema '{}' oko kursora".format(chars[0]))
            return
        # od kraja prema pocetku, da ranije pozicije ostanu tacne
        for open_pos, close_pos in sorted(set(found), key=lambda p: -p[0]):
            pad = _padding(view, open_pos, close_pos)
            view.erase(edit, sublime.Region(close_pos - pad, close_pos + 1))
            view.erase(edit, sublime.Region(open_pos, open_pos + 1 + pad))


class SurroundChangeCommand(sublime_plugin.TextCommand):
    def run(self, edit, chars):
        view = self.view
        old, new = chars[0], chars[1]
        wrap = _wrap_with(new)
        if wrap is None:
            view.window().status_message(
                "surround: ne znam par za '{}'".format(new))
            return
        left, right = wrap
        found = []
        for region in view.sel():
            pair = _find_pair(view, region.b, old)
            if pair:
                found.append(pair)
        if not found:
            view.window().status_message(
                "surround: nema '{}' oko kursora".format(old))
            return
        for open_pos, close_pos in sorted(set(found), key=lambda p: -p[0]):
            pad = _padding(view, open_pos, close_pos)
            view.replace(edit, sublime.Region(close_pos - pad, close_pos + 1), right)
            view.replace(edit, sublime.Region(open_pos, open_pos + 1 + pad), left)
