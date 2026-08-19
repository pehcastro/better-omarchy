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
| `Ctrl+B` | copy the path of the selected file, in the file manager only |
| `Ctrl+Shift+B` | copy just its name |

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

`Ctrl+B` is a bare `Ctrl+letter`, which Hyprland would normally take from every
application at once. It does not here: the binding is created when a file
manager takes focus and destroyed when it loses it, so `Ctrl+B` still belongs to
your terminal, your editor and your browser.

Not `Ctrl+C`, because the script sends `Ctrl+C` to the file manager to find out
what is selected, so it cannot also be the trigger.

`hypr/bindings.lua` lists the classes that count as a file manager. Add yours to
`file_managers` if it is not there.

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

The scale is re-applied on `monitor.added`, not just at load. Waking from sleep,
closing and opening the lid, and plugging a display all re-add the output, and
whatever scale Hyprland picks at that moment otherwise wins: the screen ends up
at 2x and stays there until the next reload. `Super+/` also changes the scale,
which is easy to hit by accident, and this puts it back on the next monitor
event rather than leaving you squinting.

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
