# display-local

Your monitor layout. The one file that is wrong on every other machine, so it is
gitignored and this unit ships an example instead.

## Setting it up

```bash
cd units/display-local/hypr
cp monitors.lua.example monitors.lua
$EDITOR monitors.lua
bo add display-local
```

`hyprctl monitors all` lists what you have and every mode each one takes.

`bo add` links whatever `.lua` it finds, so the example on its own links
nothing. Nothing happens until you make the copy.

## Common shapes

```lua
-- Everything, at 1x
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- One named monitor
hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait (transform 1 is 90 degrees, 3 is 270)
hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
```
