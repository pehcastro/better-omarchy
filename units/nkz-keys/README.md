# nkz-keys

One person's Hyprland setup. Useful as an example of what a personal unit looks
like; probably not what you want turned on.

## Keys

| Key | What it does |
|---|---|
| `Alt+F4` | close the focused window |
| `Super+E` | open the file manager |
| `Super+B` | open the browser |
| `Super+R` | open the app menu |
| `Ctrl+Shift+G` | copy the path of the file selected in the file manager |
| `Ctrl+Shift+Alt+G` | copy just its name |

None replaces an Omarchy default. `Super+W` still closes a window and
`Super+Shift+B` still opens a browser.

## Copying a file path

Select a file in Nautilus, press `Ctrl+Shift+G`, and its path is on the
clipboard as plain text.

Hyprland cannot ask Nautilus what is selected, so the script sends `Ctrl+C` to
the focused window, which every file manager answers by putting a `text/uri-list`
on the clipboard, then rewrites that list as paths. It saves what the clipboard
held first and puts it back when nothing was selected, so a misfire does not
cost you what you had copied. Paths are percent-decoded, because a URI escapes
spaces and a path with `%20` in it is not a path.

`Ctrl+Shift+G` rather than a bare `Ctrl+G`: Hyprland takes a binding from every
application at once, so a bare one would stop `Ctrl+G` working in the terminal,
the editor and the browser too.

## Monitors

`hypr/monitors.lua` is gitignored, because the same file on another machine is
wrong. Copy the example and edit it:

```bash
cd units/nkz-keys/hypr
cp monitors.lua.example monitors.lua
$EDITOR monitors.lua
```

`hyprctl monitors all` lists what you have and every mode each one takes. `bo
add` links whatever `.lua` it finds, so the example alone links nothing.

## Making your own

```bash
bo new unit my-keys
```

Then edit `hypr/my-keys.lua`. To take a key Omarchy already uses, call
`hl.unbind` first or both bindings fire:

```lua
hl.unbind("SUPER + F")
o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })
```

`bo status` lists every key each linked unit claims and flags two units fighting
over one.
