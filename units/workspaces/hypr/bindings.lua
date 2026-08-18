-- SUPER+F2 opens the rename panel on the active workspace, the same panel a
-- right-click on any workspace button opens. F2 to rename, as in a file manager.

o.bind("SUPER + F2", "Rename workspace", "omarchy-shell shell toggle bo.workspaces")

-- Keep 1-10 in the bar even when empty. Names live in the widget's own entry in
-- shell.json, not here, so a rename needs no Hyprland reload.
for id = 1, 10 do
  hl.workspace_rule({ workspace = tostring(id), persistent = true })
end
