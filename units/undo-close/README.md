# undo-close

`Super+Z` reopens the window you closed last. Exactly one: press it twice and
the second press does nothing.

## How it works

`omacast-window-history-daemon` reads Hyprland's event socket and records each
window's command line when it opens. `omarchy-window-reopen` reads the last
entry, runs it, and empties the file.

It stores one entry, not a stack. A stack meant that pressing again walked back
through windows you closed hours ago, which is never what the key means.

## Three things that were hard

Chrome and Electron rewrite their process title, so `/proc/PID/cmdline` collapses
to a single argv entry with spaces in it and cannot be re-executed. The daemon
notices and blanks the command; reopen then falls back to `gio launch` on the
window class's `.desktop` file.

The daemon seeds from `hyprctl clients` at startup, or every window that was
already open is invisible to it.

`socat` inherits the lock file descriptor, so it is started with `9>&-` and a
`trap 'kill 0'`. Without that a stray socat holds the lock and every later start
exits silently, looking like the daemon simply refused to run.

## Files

`bin/omacast-window-history-daemon`, `bin/omarchy-window-reopen`,
`hypr/reopen.lua`. State at `~/.local/state/omarchy/closed-windows`.
