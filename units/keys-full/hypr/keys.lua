-- One way in. Super+K opens OmarchyCast and nothing else opens a launcher.
--
-- The Omarchy menu keeps its bar icon and Super+Shift+F12, so this is
-- recoverable without editing any config.

hl.unbind("SUPER + K")
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")

o.bind("SUPER + K", "OmarchyCast", "omarchy-shell shell toggle bo.omarchycast")

-- The keybindings cheatsheet loses Super+K, so it moves to H for help.
o.bind("SUPER + H", "Keybindings", "omarchy-menu-keybindings")
