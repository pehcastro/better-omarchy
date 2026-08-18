-- Reopen the most recently closed window.
--
-- The daemon reads Hyprland's socket2 and records each window's command line at
-- open time, so the binding has something to relaunch. It stores exactly one
-- entry: reopen consumes it, and a second press has nothing to do.

o.exec_on_start("omarchy-window-history-daemon")
o.bind("SUPER + Z", "Reopen closed window", "omarchy-window-reopen")
