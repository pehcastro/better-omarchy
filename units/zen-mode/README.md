# zen-mode

A workspace holding one tiled window drops its gaps, border and rounding, so a
single app reads as full screen. Open a second window and all three come back.

Nothing is toggled and nothing is remembered: it follows what is on the
workspace, so you get the effect by closing a window rather than by pressing
anything.

## How

One Hyprland workspace rule in `hypr/looknfeel.lua`:

```lua
hl.workspace_rule({
  workspace = "w[tv1]",
  gaps_in = 0, gaps_out = 0,
  no_border = true, no_rounding = true,
})
```

`w[tv1]` selects a workspace with exactly one tiled, visible window. A floating
window does not count, which is why a floating terminal over your editor does
not bring the gaps back.

## Changing it

Keep the gaps but lose the border by dropping the two `gaps_*` lines. Check what
is live with `hyprctl workspacerules`.
