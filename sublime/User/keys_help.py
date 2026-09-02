"""F1 -> cheatsheet svih mapa; plus pretraga kroz quick panel.

KEYS.md pravi bin/dot-keys iz samih configa (komentari u keymapu, `desc` u
init.lua, komentari u helix config.toml), pa se ne odrzava rucno. Ove
komande ga regenerisu pre otvaranja, da nikad ne gledam ustajalu verziju.

    keys_cheatsheet   regeneriraj i otvori KEYS.md
    keys_search       quick panel preko svih mapa, skok na red u KEYS.md

GUI aplikacije na macOS-u ne dobijaju shell PATH, pa se dot-keys trazi na
standardnim lokacijama, ne samo kroz which() — ista zamka kao sa delta.
"""

import os
import re
import shutil
import subprocess
import threading

import sublime
import sublime_plugin


DOT_KEYS_PATHS = (
    os.path.expanduser("~/repos/me/dotfiles/bin/dot-keys"),
    os.path.expanduser("~/.local/bin/dot-keys"),
    os.path.expanduser("~/dotfiles/bin/dot-keys"),
)

# red u tabeli: | `key` | opis ili komanda |
ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*$")
HEADING_RE = re.compile(r"^(#{1,3})\s+(.*)$")


def _dot_keys_bin():
    found = shutil.which("dot-keys")
    if found:
        return found
    for path in DOT_KEYS_PATHS:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


def _regenerate():
    """Vrati (putanja do KEYS.md, greska)."""
    binary = _dot_keys_bin()
    if not binary:
        return None, "dot-keys nije nadjen (bin/dot-keys u dotfiles repou)"
    try:
        out = subprocess.run([binary], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, timeout=30)
    except (OSError, subprocess.SubprocessError) as err:
        return None, "dot-keys pao: {}".format(err)
    if out.returncode != 0:
        detail = out.stderr.decode("utf-8", "replace").strip().split("\n")[-1]
        return None, "dot-keys izasao sa {}: {}".format(out.returncode, detail)
    path = out.stdout.decode("utf-8", "replace").strip()
    if not path or not os.path.exists(path):
        return None, "dot-keys nije napisao KEYS.md"
    return path, None


class KeysCheatsheetCommand(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window

        def work():
            path, err = _regenerate()
            if err:
                sublime.set_timeout(lambda: window.status_message("keys: " + err), 0)
                return
            sublime.set_timeout(lambda: window.open_file(path), 0)

        threading.Thread(target=work, daemon=True).start()


class KeysSearchCommand(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window

        def work():
            path, err = _regenerate()
            if err:
                sublime.set_timeout(lambda: window.status_message("keys: " + err), 0)
                return

            # Kontekst je hijerarhija naslova: "Sublime Text / PR REVIEW".
            # Bez toga se ne vidi da li je mapa iz nvim-a ili iz Sublime-a.
            items, targets = [], []
            trail = {}
            with open(path) as handle:
                for row, line in enumerate(handle, start=1):
                    heading = HEADING_RE.match(line)
                    if heading:
                        level = len(heading.group(1))
                        trail[level] = heading.group(2).strip()
                        for deeper in list(trail):
                            if deeper > level:
                                del trail[deeper]
                        continue
                    match = ROW_RE.match(line)
                    if not match:
                        continue
                    key, what = match.group(1), match.group(2)
                    if key.strip() in ("---", "Key"):
                        continue
                    where = " / ".join(trail[k] for k in sorted(trail) if k > 1)
                    items.append([key, "{}   —   {}".format(what.strip("` "), where)])
                    targets.append(row)

            if not items:
                sublime.set_timeout(
                    lambda: window.status_message("keys: nema mapa u KEYS.md"), 0)
                return

            def show():
                def picked(index):
                    if index < 0:
                        return
                    window.open_file("{}:{}".format(path, targets[index]),
                                     sublime.ENCODED_POSITION)
                window.show_quick_panel(items, picked)

            sublime.set_timeout(show, 0)

        threading.Thread(target=work, daemon=True).start()
