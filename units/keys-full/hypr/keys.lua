-- One way in. Super+K opens OmaCast and nothing else opens a launcher.
--
-- The Omarchy menu keeps its bar icon and Super+Shift+F12, so this is
-- recoverable without editing any config.

hl.unbind("SUPER + K")
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")

o.bind("SUPER + K", "OmaCast", "omarchy-shell shell toggle bo.omacast")

-- The keybindings cheatsheet loses Super+K, so it moves to H for help.
o.bind("SUPER + H", "Keybindings", "omarchy-menu-keybindings")
