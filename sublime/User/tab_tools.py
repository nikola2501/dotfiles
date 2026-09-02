"""Pomeranje tabova unutar panela.

Sublime nema ugradjenu komandu za ovo. `select_by_index` samo fokusira tab
N, `move_to_group` prebacuje u drugi panel — nista ne menja redosled unutar
panela. API ima window.set_view_index(), pa je posao trivijalan.

Semantika je "prebaci na to mesto", ne "zameni sa tim tabom": tab se izvadi
i ubaci na trazenu poziciju, ostali se pomere. Isto sto radi drag-and-drop
tabom, samo tasterom.

    move_tab_to_index   {"index": N}   1-indeksirano, kao super+1..9
                                       koje fokusiraju tabove
"""

import sublime_plugin


class MoveTabToIndexCommand(sublime_plugin.WindowCommand):
    def run(self, index):
        window = self.window
        view = window.active_view()
        if view is None:
            return

        group, current = window.get_view_index(view)
        if group < 0:
            return

        count = len(window.views_in_group(group))
        # 1-indeksirano izvana, jer super+1..9 u ST-u broje tabove od 1
        target = max(0, min(count - 1, int(index) - 1))
        if target == current:
            return

        window.set_view_index(view, group, target)

    def is_enabled(self):
        view = self.window.active_view()
        if view is None:
            return False
        group, _ = self.window.get_view_index(view)
        return group >= 0 and len(self.window.views_in_group(group)) > 1
