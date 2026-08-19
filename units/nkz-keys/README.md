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
| `Super+`` ` | back to the workspace you came from, and again to return |
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

Pick a scale wherever you like. The Display panel in the bar writes it, this
file reads it back, and a reload keeps it.

Omarchy's own precedence has the config file win: clamshell prefers the scale it
parses out of `monitors.lua` and only falls back to its saved state, so a scale
picked in the panel was lost at the next reload. This file reads that state and
treats it as the answer when it is there, and records the live scale on
`monitor.layout_changed` so a panel change is remembered. Delete
`~/.local/state/omarchy/toggles/hypr/internal-monitor-scale` to go back to the
default in this file.

`bo` links this file twice: into `modules.d` like any other unit Lua, and to
`~/.config/hypr/monitors.lua`. That second path is not decoration.
`omarchy-hyprland-monitor-clamshell` runs on every wake, parses that exact file
to learn the scale to restore, and falls back to a hardcoded `2` when it is not
there. That is why the screen kept coming back from sleep at twice the size.

The local is named `omarchy_monitor_scale` for the same reason: that parser
resolves a bare word through the locals in the file, and that is the name it
looks for last.

The scale is also re-applied on `monitor.added`, not just at load. Waking from sleep,
closing and opening the lid, and plugging a display all re-add the output, and
whatever scale Hyprland picks at that moment otherwise wins: the screen ends up
at 2x and stays there until the next reload. This unit also unbinds `Super+/` and
`Super+Alt+/`, Omarchy's scaling keys: both are one key from `Super+Shift+/` and
hitting one leaves the screen at 2x with nothing on screen saying why. Scaling
belongs in the Display panel, where it is a deliberate choice.

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
