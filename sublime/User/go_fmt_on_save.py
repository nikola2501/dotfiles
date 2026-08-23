import subprocess
import sublime
import sublime_plugin


class FmtOnSave(sublime_plugin.EventListener):
    def on_pre_save(self, view):
        fname = view.file_name()
        if not fname:
            return
        if fname.endswith(".go"):
            view.run_command("go_fmt")
        elif fname.endswith((".c", ".h")):
            view.run_command("clang_fmt")


class GoFmtCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        self._fmt(edit, ["gofmt"])

    def _fmt(self, edit, cmd):
        content = self.view.substr(sublime.Region(0, self.view.size()))
        result = subprocess.run(cmd, input=content.encode(), capture_output=True)
        if result.returncode == 0:
            formatted = result.stdout.decode()
            if formatted != content:
                self.view.replace(edit, sublime.Region(0, self.view.size()), formatted)
        elif result.stderr:
            print(f"{cmd[0]}:", result.stderr.decode())


class ClangFmtCommand(GoFmtCommand):
    def run(self, edit):
        self._fmt(edit, ["clang-format"])
