-- Keys that behave the way they do on Windows, for hands that learned there.

o.bind("ALT + F4", "Close window", hl.dsp.window.close())
o.bind("SUPER + E", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + R", "Launch apps", "omarchy-menu toggle apps")

-- Copy the path of whatever is selected in the file manager.
--
-- Ctrl+B, a bare Ctrl+letter, which Hyprland would normally take from every
-- application at once. It does not here: the binding is created and destroyed
-- as the file manager gains and loses focus, so Ctrl+B still belongs to your
-- terminal, your editor and your browser.
--
-- Not Ctrl+C, because the script sends Ctrl+C to the file manager to find out
-- what is selected, so it cannot also be the trigger.

local file_managers = { "org.gnome.Nautilus", "nautilus", "thunar", "org.kde.dolphin", "nemo" }

local copy_path_binds = {}

local function is_file_manager(class)
  for _, name in ipairs(file_managers) do
    if class == name then return true end
  end
  return false
end

local function bind_copy_path()
  if #copy_path_binds > 0 then return end
  copy_path_binds = {
    hl.bind("CTRL + B", hl.dsp.exec_cmd("copy-file-path"), { description = "Copy file path" }),
    hl.bind("CTRL + SHIFT + B", hl.dsp.exec_cmd("copy-file-path --name"), { description = "Copy file name" }),
  }
end

local function unbind_copy_path()
  for _, keybind in ipairs(copy_path_binds) do
    keybind:unbind()
  end
  copy_path_binds = {}
end

hl.on("window.active", function(window)
  if window and is_file_manager(tostring(window.class)) then
    bind_copy_path()
  else
    unbind_copy_path()
  end
end)

-- Super+` returns to the workspace you came from, and pressing it again brings
-- you back. Omarchy has this on Super+Ctrl+Tab, which is a chord; this is the
-- key next to 1, where the thing that flips between two places belongs.
--
-- Not Super+Tab: that walks forward through every workspace in order, which is
-- a different question. This one only ever knows about two.
o.bind("SUPER + grave", "Previous workspace", hl.dsp.focus({ workspace = "previous" }))
