-- A workspace holding a single tiled window reads as full screen. Open a second
-- window and the gaps, border and rounding all come back.
-- `w[tv1]` selects a workspace with exactly one tiled, visible window.

hl.workspace_rule({
  workspace = "w[tv1]",
  gaps_in = 0,
  gaps_out = 0,
  no_border = true,
  no_rounding = true,
})
