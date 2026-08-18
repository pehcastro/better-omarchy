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

None replaces an Omarchy default. `Super+W` still closes a window and
`Super+Shift+B` still opens a browser.

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
