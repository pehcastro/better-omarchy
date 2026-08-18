-- Keys that behave the way they do on Windows, for hands that learned there.

o.bind("ALT + F4", "Close window", hl.dsp.window.close())
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + R", "Launch apps", "omarchy-menu toggle apps")

-- Copy the path of whatever is selected in the file manager.
--
-- Ctrl+Shift+G, because the index finger is already there for Ctrl+C and
-- Ctrl+V. A bare Ctrl+letter is not an option: Hyprland takes a binding from
-- every application at once, so Ctrl+G would stop working in the terminal, the
-- editor and the browser too. Ctrl+Shift+G is the least claimed key in that
-- reach.
o.bind("CTRL + SHIFT + G", "Copy file path", "copy-file-path")
o.bind("CTRL + SHIFT + ALT + G", "Copy file name", "copy-file-path --name")
