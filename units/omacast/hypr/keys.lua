-- What opens Omacast.
--
-- Three presets, one line to switch. Editing this file is the whole
-- configuration: nothing reads a setting, because a Hyprland keybinding has to
-- be Lua and reaching into a JSON file from here would be worse than a variable.
--
--   "additive"  Super+Shift+K, and every Omarchy default survives.
--   "balanced"  Super+K, with the keybindings cheatsheet moved to Super+H.
--   "full"      the same, and nothing else opens a launcher any more.
--
-- The Omarchy menu keeps its bar icon and Super+Shift+F12 in all three, so
-- "full" is recoverable without editing config.

local preset = "balanced"

local function open_omacast(key)
  o.bind(key, "Omacast", "omarchy-shell shell toggle bo.omacast")
end

if preset == "additive" then
  open_omacast("SUPER + SHIFT + K")
else
  -- Super+K is Omarchy's keybindings cheatsheet, so it moves to H for help.
  hl.unbind("SUPER + K")
  open_omacast("SUPER + K")
  o.bind("SUPER + H", "Keybindings", "omarchy-menu-keybindings")

  if preset == "full" then
    hl.unbind("SUPER + SPACE")
    hl.unbind("SUPER + ALT + SPACE")
  end
end
