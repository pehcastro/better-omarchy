-- Super+K opens OmarchyCast, the way Cmd+K opens a command bar almost
-- everywhere else. The Omarchy menu and the apps menu keep their keys.

hl.unbind("SUPER + K")
o.bind("SUPER + K", "OmarchyCast", "omarchy-shell shell toggle bo.omarchycast")

-- The keybindings cheatsheet loses Super+K, so it moves to H for help.
o.bind("SUPER + H", "Keybindings", "omarchy-menu-keybindings")
