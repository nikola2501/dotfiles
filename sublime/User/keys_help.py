"""shift+F1 -> pretraziv spisak SVIH Sublime mapa, enter izvrsi komandu.

Samo Sublime. nvim ima svoj `<leader>?` (fzf picker preko pravih keymapa),
helix ima hx-keys — ovde se ne mesaju.

Cita se keymap direktno, ne KEYS.md, jer panel mora da zna komandu i njene
argumente da bi je mogao izvrsiti.

Opis mape se trazi u tri koraka, prvi koji postoji pobedjuje:

  1. // komentar na mapi: trailing na istom redu, ili jedan red iznad
     (visielinijski blok iznad je proza o grupi i ne koristi se)
       { "keys": ["f8"], "command": "lsp_hover" },  // Hover dokumentacija
  2. caption iz bilo kog .sublime-commands (User, instalirani paketi, ST
     default) — tako `pr_diff` dobije "PR: diff vs base branch (all files)"
     bez da ista duplo pisem
  3. ime komande, ocisceno od donjih crta

Grupni // komentar iznad bloka mapa se NE koristi kao opis — to je proza o
celoj grupi, i kao opis pojedine mape daje besmislice. Sekcija se vidi u
drugom redu unosa.

Rangiranje radi fzf, ne ST i ne ja. ST-ov matcher je subsequence koji jako
ceni poklapanja na granici reci, pa mu se "git" poklopi sa "**g**s
**i**nterface **t**oggle help" i to izbaci ispred "git: commit", a
show_quick_panel nema flag za sortiranje — dok ST filtrira, poredak nije
moj. Prvo sam napisao svoj scorer i to je bila greska: `fzf --filter QUERY`
radi isto neinteraktivno, bez TTY-a, algoritmom testiranim neuporedivo vise
od bilo cega mog.

Upit ide kroz input panel, kroz `fzf --filter`, pa u quick panel vec
sortiran. Vise reci je AND (fzf tako radi): "pr diff" ili "harpoon 3" suze
na jedno. Prazan upit daje sve mape.

Bez fzf-a ostaje obicno substring filtriranje — bez rangiranja, ali radi.

    keys_search       upit -> rangirani rezultati -> enter izvrsi
    keys_cheatsheet   regeneriraj i otvori KEYS.md (bin/dot-keys)
"""

import json
import os
import re
import shutil
import subprocess
import threading
import zipfile

import sublime
import sublime_plugin


DOT_KEYS_PATHS = (
    os.path.expanduser("~/repos/me/dotfiles/bin/dot-keys"),
    os.path.expanduser("~/.local/bin/dot-keys"),
    os.path.expanduser("~/dotfiles/bin/dot-keys"),
)

# GitSavvy tasteri vaze samo unutar njegovih view-ova; `o` je taj koji stalno
# zaboravim, pa idu u spisak, ali obelezeni.
GS_VIEWS = {
    "git_savvy.diff_view": "GitSavvy diff",
    "git_savvy.inline_diff_view": "GitSavvy inline diff",
    "git_savvy.status_view": "GitSavvy status",
}

FZF_PATHS = (
    "/opt/homebrew/bin/fzf",
    "/usr/local/bin/fzf",
    os.path.expanduser("~/.fzf/bin/fzf"),
    "/usr/bin/fzf",
)

SECTION_RE = re.compile(r"^//\s*---+\s*(.*?)\s*---+\s*$")
TRAILING_RE = re.compile(r"//\s*(.+?)\s*$")


def _strip_jsonc(text):
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    text = re.sub(r"//[^\"\n]*$", "", text, flags=re.M)
    return re.sub(r",(\s*[\]}])", r"\1", text)


def _fzf_bin():
    found = shutil.which("fzf")
    if found:
        return found
    for path in FZF_PATHS:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


def _fzf_rank(query, triggers):
    """Indeksi u fzf poretku, ili None ako fzf nije nadjen."""
    binary = _fzf_bin()
    if not binary:
        return None
    # indeks u prvoj koloni, fzf poklapa samo drugu (--nth=2..), pa je
    # mapiranje rezultata nazad egzaktno i kad su dva trigger-a ista
    payload = "".join("{}\t{}\n".format(i, t) for i, t in enumerate(triggers))
    try:
        out = subprocess.run(
            [binary, "--filter", query, "--delimiter", "\t", "--nth", "2.."],
            input=payload.encode("utf-8"),
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    order = []
    for line in out.stdout.decode("utf-8", "replace").splitlines():
        head_col = line.split("\t", 1)[0]
        if head_col.isdigit():
            order.append(int(head_col))
    return order


def _packages_dir():
    return os.path.dirname(sublime.packages_path())


def _captions():
    """{komanda: caption} iz svih .sublime-commands koje nadjem."""
    found = {}

    def ingest(raw):
        try:
            data = json.loads(_strip_jsonc(raw))
        except ValueError:
            return
        for entry in data:
            if not isinstance(entry, dict):
                continue
            command, caption = entry.get("command"), entry.get("caption")
            if command and caption:
                found.setdefault(command, caption)

    user = os.path.join(sublime.packages_path(), "User")
    if os.path.isdir(user):
        for name in sorted(os.listdir(user)):
            if name.endswith(".sublime-commands"):
                try:
                    with open(os.path.join(user, name)) as handle:
                        ingest(handle.read())
                except OSError:
                    pass

    roots = [os.path.join(_packages_dir(), "Installed Packages")]
    exe = os.path.dirname(sublime.executable_path())
    roots.append(os.path.join(exe, "Packages"))
    for root in roots:
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            if not name.endswith(".sublime-package"):
                continue
            try:
                with zipfile.ZipFile(os.path.join(root, name)) as archive:
                    for inner in archive.namelist():
                        if inner.endswith(".sublime-commands"):
                            ingest(archive.read(inner).decode("utf-8", "replace"))
            except (OSError, zipfile.BadZipFile):
                pass
    return found


def _parse_keymap(text, default_section):
    """[(keys, command, args, trailing_desc, section)] iz JSON-a s komentarima."""
    out = []
    section = default_section
    pending = []
    buf, depth = None, 0

    for line in text.split("\n"):
        stripped = line.strip()
        if buf is None:
            head = SECTION_RE.match(stripped)
            if head:
                section, pending = head.group(1), []
                continue
            if stripped.startswith("//"):
                text_ = stripped[2:].strip()
                if text_:
                    pending.append(text_)
                continue
            if not stripped:
                pending = []
                continue
            if not stripped.startswith("{"):
                continue
            buf, depth = "", 0

        buf += line + "\n"
        depth += line.count("{") - line.count("}")
        if depth > 0:
            continue

        last = buf.rstrip().split("\n")[-1]
        tail = TRAILING_RE.search(last)
        trailing = tail.group(1) if tail else None
        # komentar prvo, pa onda zarez: inace ostane "{...},  // opis" ->
        # "{...}," i json.loads pada na trailing zapeti
        chunk = _strip_jsonc(buf).strip().rstrip(",")
        try:
            entry = json.loads(chunk)
        except ValueError:
            buf, pending = None, []
            continue
        keys = entry.get("keys") or []
        command = entry.get("command")
        if command:
            # jednolinijski komentar iznad mape je opis; blok od vise linija
            # je proza o celoj grupi i kao opis daje besmislice
            above = pending[0] if len(pending) == 1 else None
            out.append((" then ".join(keys), command, entry.get("args") or {},
                        trailing or above, section))
        buf, pending = None, []
    return out


def _gitsavvy_bindings():
    root = os.path.join(_packages_dir(), "Installed Packages")
    path = os.path.join(root, "GitSavvy.sublime-package")
    if not os.path.exists(path):
        return []
    try:
        with zipfile.ZipFile(path) as archive:
            raw = archive.read("Default.sublime-keymap").decode("utf-8", "replace")
    except (OSError, KeyError, zipfile.BadZipFile):
        return []

    out, seen = [], set()
    pattern = re.compile(
        r"\{[^{]*?\"keys\"\s*:\s*\[(.*?)\].*?\"command\"\s*:\s*\"(\w+)\"(.*?)\n\s*\}", re.S)
    for match in pattern.finditer(raw):
        keys_raw, command, rest = match.group(1), match.group(2), match.group(3)
        for setting, label in GS_VIEWS.items():
            if setting not in rest:
                continue
            keys = " ".join(re.findall(r'"([^"]+)"', keys_raw))
            if (keys, command, label) in seen:
                continue
            seen.add((keys, command, label))
            out.append((keys, command, {}, None, label + " (samo u tom view-u)"))
    return out


def _in_gitsavvy_view(window):
    view = window.active_view()
    if view is None:
        return False
    settings = view.settings()
    return any(settings.get(name) for name in GS_VIEWS)


def _entries():
    captions = _captions()
    user_keymap = os.path.join(sublime.packages_path(), "User",
                               "Default.sublime-keymap")
    binds = []
    if os.path.exists(user_keymap):
        with open(user_keymap) as handle:
            binds = _parse_keymap(handle.read(), "Moje mape")
    binds += _gitsavvy_bindings()

    items, actions = [], []
    for keys, command, args, desc, section in binds:
        label = desc or captions.get(command) or command.replace("_", " ")
        shown = command
        if args:
            shown += " " + json.dumps(args, ensure_ascii=False)
        # QuickPanelItem: samo `trigger` se poklapa sa upitom, `details` i
        # `annotation` su prikaz. Zato taster i opis idu u trigger, a ime
        # komande i sekcija ostaju van poklapanja — inace "git" scatter-matchuje
        # "focus_group ... Pane naviga(t)ion" i takve besmislice.
        gs_view = section.startswith("GitSavvy ") and "view-u" in section
        kind = ((sublime.KIND_ID_NAVIGATION, "g", "GitSavvy view") if gs_view
                else (sublime.KIND_ID_FUNCTION, "k", "Key"))
        trigger = "{}   —   {}".format(keys, label)
        items.append(sublime.QuickPanelItem(
            trigger, details=shown, annotation=section, kind=kind))
        actions.append((command, args, trigger, gs_view))
    return items, actions


class KeysSearchCommand(sublime_plugin.WindowCommand):
    """Upit kroz input panel, rangiranje moje, enter izvrsava komandu."""

    def run(self):
        items, actions = _entries()
        if not items:
            self.window.status_message("keys: nisam nasao ni jednu mapu")
            return
        self.items, self.actions = items, actions
        self.window.show_input_panel(
            "keys ({} mapa):".format(len(items)), "",
            self.on_done, self.on_change, None)

    def _ranked(self, query):
        prefer_gs = _in_gitsavvy_view(self.window)

        def in_context(index):
            # GitSavvy view tasteri se iz obicnog fajla ne mogu ni izvrsiti,
            # pa idu nize; u njegovom view-u je obrnuto. Nista se ne izbacuje
            # iz spiska, samo se rangira drugacije.
            return self.actions[index][3] == prefer_gs

        if not query.strip():
            return sorted(range(len(self.items)),
                          key=lambda i: (not in_context(i), i))

        triggers = [action[2] for action in self.actions]
        order = _fzf_rank(query, triggers)
        if order is None:
            self.window.status_message(
                "keys: fzf nije nadjen (brew install fzf) — filtriram bez rangiranja")
            needle = query.lower()
            order = [i for i, t in enumerate(triggers) if needle in t.lower()]

        # stabilno: fzf poredak ostaje unutar grupe, kontekst odlucuje grupu
        return sorted(order, key=lambda i: not in_context(i))

    def on_change(self, query):
        order = self._ranked(query)
        if not order:
            self.window.status_message("keys: nema poklapanja za \"{}\"".format(query))
            return
        self.window.status_message("keys: {} poklapanja — prvo: {}".format(
            len(order), self.items[order[0]].trigger))

    def on_done(self, query):
        order = self._ranked(query)
        if not order:
            self.window.status_message("keys: nema poklapanja")
            return
        if len(order) == 1:
            command, args = self.actions[order[0]][:2]
            self.window.run_command(command, args)
            return

        shown = [self.items[index] for index in order]

        def picked(choice):
            if choice < 0:
                return
            command, args = self.actions[order[choice]][:2]
            # run_command na prozoru kaskadira: window -> aktivni view ->
            # application, pa rade i TextCommand mape (npr. GitSavvy `o`)
            self.window.run_command(command, args)

        # ST bi ovu listu ponovo sortirao da se u njoj kuca, ali je vec
        # rangirana i najbolji je selektovan, pa je dovoljan enter
        self.window.show_quick_panel(shown, picked, selected_index=0)


def _dot_keys_bin():
    found = shutil.which("dot-keys")
    if found:
        return found
    for path in DOT_KEYS_PATHS:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


class KeysCheatsheetCommand(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window

        def work():
            binary = _dot_keys_bin()
            if not binary:
                sublime.set_timeout(
                    lambda: window.status_message("keys: dot-keys nije nadjen"), 0)
                return
            try:
                out = subprocess.run([binary], stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE, timeout=30)
            except (OSError, subprocess.SubprocessError) as err:
                msg = "keys: dot-keys pao: {}".format(err)
                sublime.set_timeout(lambda: window.status_message(msg), 0)
                return
            path = out.stdout.decode("utf-8", "replace").strip()
            if out.returncode != 0 or not path or not os.path.exists(path):
                sublime.set_timeout(
                    lambda: window.status_message("keys: dot-keys nije napisao KEYS.md"), 0)
                return
            sublime.set_timeout(lambda: window.open_file(path), 0)

        threading.Thread(target=work, daemon=True).start()
