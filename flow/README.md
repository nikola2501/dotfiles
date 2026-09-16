# flow

Config for [flow](https://github.com/neurocyte/flow), the Zig editor.

    ~/.config/flow/config           <- config
    ~/.config/flow/keys/flow.json   <- keys/flow.json

## The `inherit` line matters

`keys/flow.json` opens with:

```json
"settings": { "inherit": "<<builtin>>" }
```

Without it a user keymap **replaces** the built-in one outright rather than
layering over it, and every mode not listed in the file simply stops existing.
That is not obvious until something asks for one: find-all-references fetches
its results, then fails with `ERROR: mode not found: filelist` — the lookup has
no fallback, so the panel cannot open. Ten modes were missing this way
(`filelist`, `info`, `inputview`, `inspector`, `keybindview`, `log`,
`overlay/dropdown`, `overlay/dropdown-noninvasive`, `panel`, `terminal`), which
also accounts for the log view, the terminal and the inspector not opening.

It bites in `input_mode "vim"` too, and for a second reason: a namespace that
is not the default one falls back to the *user's* `flow` keymap rather than the
built-in, so a gap here propagates into `vim`, `helix` and `emacs` as well.
