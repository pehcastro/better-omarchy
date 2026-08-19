-- SUPER+F2 opens the rename panel on the active workspace, the same panel a
-- right-click on any workspace button opens. F2 to rename, as in a file manager.

o.bind("SUPER + F2", "Rename workspace", "omarchy-shell shell toggle bo.better-workspaces")

-- SUPER+= goes somewhere empty, next to the workspace number keys and shaped
-- like the + it matches in the bar. The + button calls the same command.
o.bind("SUPER + equal", "New workspace", "bo-workspace-new")

-- Workspaces are not held open any more. Keeping 1 to 10 persistent meant ten
-- of them always existed, which is exactly what the bar then had to draw and
-- what pushed the names into the clock. Hyprland makes a workspace when
-- something goes to it, which is soon enough.
