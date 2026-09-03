"""PR review flow za Sublime, poravnat sa mojim nvim configom.

Nvim ima :Greview / :Gchanged / :Gvdiff, koji diff-uju protiv merge-base
bazne grane, a ne protiv vrha te grane — main se pomera dok radis, i diff
protiv vrha uvlaci tudje commite. Ovo je isto, kroz GitSavvy.

GitSavvy sam po sebi ne zna da nadje baznu granu: `gs_diff` prima
base_commit, ali ga nesto mora izracunati. Otud ovaj plugin — detekcija baze
je ista kaskada kao git_base() u ~/.config/nvim/init.lua:

    setting "pr_review_base"  ->  origin/HEAD  ->  origin/main
                              ->  origin/master  ->  main  ->  master

Komande (palette: "PR: ..."):
    pr_diff              ceo PR: svi fajlovi i hunk-ovi vs baza
    pr_diff_file         samo trenutni fajl vs baza
    pr_diff_pick_base    isto, ali sam izaberem granu
    pr_commits           graf commit-a u ovom PR-u
    pr_show_commit       commit ciji SHA stoji na ovoj liniji

U GitSavvy diff view-u (njegovi default tasteri, `?` daje pun spisak):
    j / k    hunk gore-dole          N / P    prethodni/sledeci fajl
    o        otvori PRAVI fajl na tom hunku
    O        otvori baznu reviziju tog hunka
    tab      staged/unstaged         +/-      vise/manje konteksta

Staging je namerno iskljucen (disable_stage), da `h`/`H`/super-enter ne
menjaju index dok citam tudji kod.

GitSavvy diff je unified, tekst kao `git diff`. Probao sam side-by-side kroz
Sublime Merge i kroz `delta --side-by-side`; oba su ispala gadnija od
unified-a i izbacena su. Ako ikad opet zatreba, ST nema diff engine, pa
svako side-by-side ovde znaci renderovanje teksta u scratch tab.
"""

import os
import re
import shutil
import subprocess
import tempfile
import threading

import sublime
import sublime_plugin


BASE_CANDIDATES = ("origin/main", "origin/master", "main", "master")


def _git(root, args):
    """Vrati stdout ili None ako git padne. Zove se iz radnog threada."""
    try:
        out = subprocess.run(
            ["git"] + list(args),
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return out.stdout.decode("utf-8", "replace").strip()


def _repo_root(window):
    """Git root iz aktivnog fajla, pa iz prvog foldera prozora."""
    candidates = []
    view = window.active_view()
    if view is not None and view.file_name():
        candidates.append(os.path.dirname(view.file_name()))
    candidates.extend(window.folders())
    for path in candidates:
        if not path or not os.path.isdir(path):
            continue
        root = _git(path, ["rev-parse", "--show-toplevel"])
        if root:
            return root
    return None


def _detect_base(window, root):
    """Ista kaskada kao git_base() u nvim configu."""
    settings = sublime.load_settings("Preferences.sublime-settings")
    view = window.active_view()
    pinned = None
    if view is not None:
        pinned = view.settings().get("pr_review_base")  # radi i per-project
    if not pinned:
        pinned = settings.get("pr_review_base")
    if pinned:
        return pinned

    # origin/HEAD je autoritativan odgovor gde je postavljen; svez klon ga
    # cesto nema, otud pogadjanje ispod.
    head = _git(root, ["rev-parse", "--abbrev-ref", "origin/HEAD"])
    if head and "/" in head:
        return head

    for cand in BASE_CANDIDATES:
        if _git(root, ["rev-parse", "--verify", "--quiet", cand]) is not None:
            return cand
    return None


def _resolve_and_run(window, on_ready, base=None):
    """Git pozivi u threadu, GitSavvy komanda na main threadu.

    GitSavvy komande moraju na main thread, a git pozivi ne smeju da blokiraju
    UI — ista greska koju sam imao u nvim-u sa buf_request_sync.
    """
    def work():
        root = _repo_root(window)
        if not root:
            sublime.set_timeout(
                lambda: window.status_message("PR review: nije git repo"), 0)
            return

        ref = base or _detect_base(window, root)
        if not ref:
            sublime.set_timeout(
                lambda: window.status_message(
                    "PR review: nema bazne grane — postavi \"pr_review_base\""), 0)
            return

        merge_base = _git(root, ["merge-base", ref, "HEAD"])
        if not merge_base:
            sublime.set_timeout(
                lambda: window.status_message(
                    "PR review: nema zajednickog pretka sa " + ref), 0)
            return

        sublime.set_timeout(lambda: on_ready(root, ref), 0)

    threading.Thread(target=work, daemon=True).start()


class PrDiffCommand(sublime_plugin.WindowCommand):
    """Ceo PR u jednom diff view-u: <leader>gm / <leader>gh iz nvim-a."""

    current_file = False

    def run(self, base=None):
        window = self.window

        def go(root, ref):
            window.run_command("gs_diff", {
                "repo_path": root,
                # A...B je git-ov merge-base diff: od tacke grananja do HEAD-a,
                # bez tudjih commit-a koji su u medjuvremenu usli u bazu
                "base_commit": "{}...HEAD".format(ref),
                "disable_stage": True,
                "current_file": self.current_file,
            })
            window.status_message("PR diff vs {} (merge-base)".format(ref))

        _resolve_and_run(window, go, base)


class PrDiffFileCommand(PrDiffCommand):
    """Samo trenutni fajl vs baza: :Gvdiff iz nvim-a."""

    current_file = True


class PrDiffPickBaseCommand(sublime_plugin.WindowCommand):
    """Kad repo nije ni main ni master, ili poredim sa release granom."""

    def run(self):
        window = self.window

        def work():
            root = _repo_root(window)
            if not root:
                sublime.set_timeout(
                    lambda: window.status_message("PR review: nije git repo"), 0)
                return
            out = _git(root, [
                "for-each-ref", "--format=%(refname:short)",
                "--sort=-committerdate", "refs/heads", "refs/remotes",
            ])
            refs = [r for r in (out or "").splitlines() if r and not r.endswith("/HEAD")]
            if not refs:
                sublime.set_timeout(
                    lambda: window.status_message("PR review: nema grana"), 0)
                return

            def show():
                def picked(idx):
                    if idx >= 0:
                        window.run_command("pr_diff", {"base": refs[idx]})
                window.show_quick_panel(refs, picked)

            sublime.set_timeout(show, 0)

        threading.Thread(target=work, daemon=True).start()


class PrCommitsCommand(sublime_plugin.WindowCommand):
    """Graf commit-a u ovom PR-u. GitSavvy sam racuna merge-base."""

    def run(self):
        window = self.window

        def go(root, ref):
            window.run_command("gs_compare_commit", {
                "base_commit": ref,
                "target_commit": "HEAD",
            })
            window.status_message("commiti vs {}".format(ref))

        _resolve_and_run(window, go)


# --- COMMIT SA LINIJE ---------------------------------------------------
# GitSavvy-jev gs_show_commit prima obavezan commit_hash, pa se ne moze
# mapirati na goli taster. Ovo je ekvivalent Gshow iz nvim configa: procita
# SHA sa trenutne linije i preda ga GitSavvy-ju.
SHA_RE = re.compile(r"\b[0-9a-f]{7,40}\b")


class PrShowCommitCommand(sublime_plugin.WindowCommand):
    """Otvori commit ciji SHA stoji na liniji pod kursorom (nvim Gshow)."""

    def run(self):
        view = self.window.active_view()
        if view is None:
            return
        selection = view.sel()
        if not len(selection):
            return

        point = selection[0].b
        # prvo rec pod kursorom, pa onda cela linija — tako kursor na SHA
        # pobedjuje drugi SHA na istoj liniji
        word = view.substr(view.word(point)).strip()
        candidates = SHA_RE.findall(word) + SHA_RE.findall(view.substr(view.line(point)))
        # ocisti ocigledne lazne pozitive: samo cifre nije SHA (broj linije,
        # timestamp), a i git ih ne bi razresio
        candidates = [c for c in candidates if not c.isdigit()]
        if not candidates:
            self.window.status_message("PR review: nema SHA na ovoj liniji")
            return

        self.window.run_command("gs_show_commit", {"commit_hash": candidates[0]})
