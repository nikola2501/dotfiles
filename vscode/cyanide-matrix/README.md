# Cyanide - Matrix for VS Code

Port of `sublime/User/mytheme/Cyanide - Matrix` to a VS Code color theme.

Source of truth for colors is `sublime/User/Cyanide - Matrix.sublime-color-scheme`
(the override on top of the tmTheme). UI colors come from
`sublime/User/mytheme/Cyanide - Matrix.sublime-theme`. When a color changes
there, change it here too. Same rule as for the Helix and nvim ports.

## Install

```sh
./install-vscode.sh
```

The script links this folder into `~/.vscode/extensions/` and sets
`workbench.colorTheme`, `editor.fontFamily` and `editor.fontSize` in the
VS Code user settings. Restart VS Code after the first install.

## Differences from Sublime that VS Code cannot express

- Matching brackets: Sublime recolors the bracket glyph crimson and
  underlines the content. VS Code can only draw a crimson border around
  the bracket. Bracket pair colorization is forced to `#aaaaaa` so
  brackets stay grey like in Sublime.
- Sidebar folder labels: Sublime uses a lighter grey for folders than for
  files. VS Code has one `sideBar.foreground` for both.
- Buttons: Sublime buttons are `#0a0a0a` with a texture border. VS Code
  buttons use `#232323` so they are visible on the `#0a0a0a` background.
- Semantic highlighting is off so colors come only from TextMate scopes,
  same as Sublime.
