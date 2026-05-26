"""
Debug helper for the SublimeText CTags plugin.

Binds command `ctags_debug_jump` that runs the SAME lookup path as
navigate_to_definition (search + ranking), but prints what tags the
plugin found, what survived ranking, and a summary — to the ST console
(View > Show Console, or Ctrl+`).

Usage:
  1) Drop this file in Packages/User/CTagsDebug.py
  2) Add a keybinding:
       { "keys": ["super+alt+d"], "command": "ctags_debug_jump" }
  3) Put caret on a symbol (e.g. ErrorCode), press the chord.
  4) Open the console and read the dump.
"""
import os
import sublime
import sublime_plugin


class CtagsDebugJumpCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        view = self.view

        try:
            from CTags.plugins import cmds, utils
            from CTags.plugins.ranking.parse import Parser
            from CTags.plugins.ranking.rank import RankMgr
        except ImportError as e:
            print("[ctags-debug] cannot import CTags plugin modules:", e)
            return

        print("=" * 60)
        print("[ctags-debug] using cmds module:", cmds.__file__)

        region = view.sel()[0]
        if region.begin() == region.end():
            region = view.word(region)
        symbol = view.substr(region)
        print(f"[ctags-debug] symbol under cursor: {symbol!r}")

        file_name = view.file_name()
        print(f"[ctags-debug] current file: {file_name}")

        tag_file_setting = utils.setting("tag_file") or ".tags"
        print(f"[ctags-debug] tag_file setting: {tag_file_setting!r}")
        tags_file = cmds.find_tags_relative_to(file_name, tag_file_setting)
        print(f"[ctags-debug] tags_file resolved: {tags_file}")

        if not tags_file:
            print("[ctags-debug] no tags file found — aborting")
            return

        paths = cmds.get_alternate_tags_paths(view, tags_file)
        print(f"[ctags-debug] alternate paths searched (in order):")
        for p in paths:
            try:
                size = os.path.getsize(p)
            except OSError:
                size = -1
            print(f"   - {p}  ({size} bytes)")

        filters = utils.compile_filters(view)
        print(f"[ctags-debug] compile_filters returned: {filters}")

        all_tags = {}
        used_path = None
        for p in paths:
            with cmds.TagFile(p, cmds.SYMBOL) as tf:
                got = tf.get_tags_dict(symbol, filters=filters)
            n = len(got.get(symbol, []))
            print(f"[ctags-debug] {p}: get_tags_dict -> {n} hits for {symbol!r}")
            if got:
                all_tags = got
                used_path = p
                break

        taglist = all_tags.get(symbol, [])
        print(f"[ctags-debug] raw taglist: {len(taglist)} entries from {used_path}")

        conf = [t for t in taglist if "confluent" in (t.get("filename") or "")]
        print(f"[ctags-debug] raw confluent matches: {len(conf)}")
        for t in conf:
            print(f"   raw: filename={t.get('filename')!r}")

        sym_line = view.substr(view.line(region))
        (row, col) = view.rowcol(region.begin())
        line_to_symbol = sym_line[:col]
        source = utils.get_source(view)
        print(f"[ctags-debug] source scope: {source!r}")

        mbrParts = Parser.extract_member_exp(line_to_symbol, source)
        print(f"[ctags-debug] mbrParts length: {len(mbrParts)}")

        rankmgr = RankMgr(region, mbrParts, view, symbol, sym_line)
        ranked = rankmgr.sort_tags(taglist)
        print(f"[ctags-debug] after sort_tags: {len(ranked)} entries")

        conf_ranked = [(i, t) for i, t in enumerate(ranked) if "confluent" in (t.get("filename") or "")]
        print(f"[ctags-debug] confluent entries surviving ranking: {len(conf_ranked)}")
        for i, t in conf_ranked:
            print(f"   ranked[{i}]: {t.get('filename')}")

        print(f"[ctags-debug] first 5 ranked:")
        for i, t in enumerate(ranked[:5]):
            print(f"   {i}: {t.get('filename')}")
        print(f"[ctags-debug] last 5 ranked:")
        start = max(0, len(ranked) - 5)
        for i, t in enumerate(ranked[start:], start=start):
            print(f"   {i}: {t.get('filename')}")
        print("=" * 60)
