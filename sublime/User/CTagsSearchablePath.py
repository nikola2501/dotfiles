"""
Patch the SublimeText CTags plugin so the quick-panel trigger (the line
ST matches against when the user types to filter) includes the filename,
not just the bare symbol.

Default plugin output is `[symbol, filename, ex_command]`. ST only fuzzy-
matches the FIRST element, so for a symbol with N hits across many files
all rows have trigger == `<symbol>` and `confluent`/`kafka` filters hit
nothing.

After this patch the trigger becomes `<symbol>    <filename>`, so typing
e.g. `confluent` filters down to the vendor entries you want.

The patch is idempotent — re-running it (ST plugin reload) won't double-
wrap.
"""
import sublime
import sublime_plugin

try:
    from CTags.plugins import cmds as _cmds
except ImportError:
    _cmds = None


def _install_patch():
    if _cmds is None:
        print("[ctags-searchable] CTags plugin not loaded yet — skipping")
        return

    if getattr(_cmds.format_tag_for_quickopen, "__searchable_patched__", False):
        return  # already patched in this ST session

    _orig_format = _cmds.format_tag_for_quickopen

    def patched_format(tag, show_path=True):
        result = _orig_format(tag, show_path)
        # original result with show_path=True: [symbol_or_path_prefix, filename, ex_command]
        if show_path and len(result) >= 2:
            # ST quick-panel filter only matches the FIRST element. Concatenate
            # symbol + filename so the filter sees both.
            result[0] = f"{result[0]}    {result[1]}"
        return result

    patched_format.__searchable_patched__ = True
    _cmds.format_tag_for_quickopen = patched_format

    # prepare_for_quickpanel captures the default formatter as a default arg
    # at MODULE LOAD time. Patching cmds.format_tag_for_quickopen alone is not
    # enough — we also need prepare_for_quickpanel to re-read the module
    # attribute on each call so it picks up our patched function.
    _orig_prep = _cmds.prepare_for_quickpanel

    def patched_prep(formatter=None):
        if formatter is None:
            formatter = _cmds.format_tag_for_quickopen
        return _orig_prep(formatter)

    patched_prep.__searchable_patched__ = True
    _cmds.prepare_for_quickpanel = patched_prep

    print("[ctags-searchable] patched format_tag_for_quickopen + prepare_for_quickpanel")


def plugin_loaded():
    # ST calls plugin_loaded after all plugins are imported, so CTags is ready.
    _install_patch()
