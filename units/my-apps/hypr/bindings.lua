-- Omarchy binds SUPER+SHIFT+W to Omawrite. Unbind before rebinding, or both
-- fire on the same key.

hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })
