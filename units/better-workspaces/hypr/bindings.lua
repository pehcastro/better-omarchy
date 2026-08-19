-- SUPER+F2 opens the rename panel on the active workspace, the same panel a
-- right-click on any workspace button opens. F2 to rename, as in a file manager.

o.bind("SUPER + F2", "Rename workspace", "omarchy-shell shell toggle bo.better-workspaces")

-- SUPER+F3 goes somewhere empty. The bar's + button calls the same thing, and
-- with the empty workspaces hidden this is the only way to reach one without
-- knowing which number is free.
o.bind("SUPER + F3", "New workspace", "bo-workspace-new")

-- Workspaces are not held open any more. Keeping 1 to 10 persistent meant ten
-- of them always existed, which is exactly what the bar then had to draw and
-- what pushed the names into the clock. Hyprland makes a workspace when
-- something goes to it, which is soon enough.
