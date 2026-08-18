# familiar-keys

The keys you already know from somewhere else.

| Key | What it does |
|---|---|
| `Alt+F4` | close the focused window |
| `Super+E` | open the file manager |
| `Super+B` | open the browser |
| `Super+R` | open the app menu |

None of these replace an Omarchy default. `Super+W` still closes a window and
`Super+Shift+B` still opens a browser, so nothing you already learned stops
working.

## Changing it

`hypr/bindings.lua`. To take a key Omarchy already uses, call `hl.unbind` first
or both bindings fire:

```lua
hl.unbind("SUPER + F")
o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })
```

`bo status` lists every key each linked unit claims and flags two units fighting
over one.
