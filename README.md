# better-omarchy

Omarchy customizations you can turn on and off one at a time, from any
marketplace.

```bash
curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
```

That installs the `bo` command, adds this repo as your first marketplace, and
lets you pick what you want. Nothing turns on without you choosing it.

## Units

Five. `bo list` shows what is on, and every unit has a README beside it.

**[omacast](units/omacast/README.md)** is the launcher, and most of what this
repo is. Apps, arithmetic, files, images, windows, music, radio, clipboard,
notes, reminders, themes, a calendar, a system dashboard and the web, in one
box. Everything it answers ships inside it, including which key opens it:
`units/omacast/hypr/keys.lua` has three presets and one line to switch.

**[workspace-names](units/workspace-names/README.md)** puts workspace names in
the bar instead of numbers, with `Super+F2` to rename the one you are on.

**[undo-close](units/undo-close/README.md)** reopens the window you closed last,
on `Super+Z`. Exactly one: press twice and the second press does nothing.

**[zen-mode](units/zen-mode/README.md)** lets a lone tiled window fill its
workspace, with no gaps, border or rounding. Open a second and all three return.

**[nkz-keys](units/nkz-keys/README.md)** is one person's setup: `Alt+F4`,
`Super+E`, `Super+B`, `Super+R`, and a `monitors.lua` that is gitignored because
that file is wrong on any other machine. Copy it, do not add it.

### Things that are not units

Some customizations are one command and do not need a folder:

```bash
omarchy toggle idle stay-awake     # never lock or dim on idle
omarchy toggle nightlight
omarchy theme set catppuccin       # or type theme: in the launcher
```

## The launcher

See [units/omacast/README.md](units/omacast/README.md) for what you can type,
every key, the settings file, and how to write your own extension. The short
version:

```
firefox                    apps, commands and quicklinks together
2+2*10                     the answer, large
27 november 2027           the day of week, and how far away
file:report format:pdf     files, filtered
img:                       thumbnails, with dimensions
spotify:daft punk          search and play, no account needed
note:standup               that note, or the offer to write it
alarm:25m tea              a reminder, said the way you would say it
sys:                       battery, memory, disk, uptime
```

`Enter` runs the primary action, `Shift+Enter` the second, `Ctrl+Enter` asks a
model and streams the answer in, `Ctrl+K` shows the rest.

## bo

```
bo list                 every unit available, and whether it is on
bo search <term>        find a unit by name, summary, category or tag
bo info <unit>          everything known about one unit
bo status               what is on, plus keybinding conflicts

bo add [unit...]        turn units on (no argument opens a picker)
bo remove [unit...]     turn units off (no argument opens a picker)

bo new unit <name>      start a unit here, filled in and ready to add
bo new extension <name> start a unit whose job is one launcher keyword

bo update               fetch every marketplace, show what changed, apply
bo outdated             linked units whose marketplace moved on
bo relink               apply those changes

bo market ...           add, remove and inspect marketplaces
bo doctor               check every linked unit's dependencies exist
bo validate             run omarchy plugin validate on every plugin unit
bo registry             rebuild registry.json (for marketplace authors)
bo sync                 copy the live shell.json into this checkout
bo version              what this is and where it lives
```

`bo update` prints a per-unit changelog before it applies anything, so you see
what changed, which of it you actually have on, and whether the author bumped
the version:

```
better-omarchy
  changed  on workspace-names      0.1.0 -> 0.2.0
  new         clipboard            0.1.0  Clipboard history in the bar
  changed     cpu-meter            0.1.0 (content changed, version did not)
  updated d5d89fe4451b -> 8c0f1a92be40
```

## Marketplaces

A marketplace is a git repo holding units plus a `registry.json`. This repo is
one. Point `bo` at anyone else's and their units appear in your list next to
these:

```bash
bo market add https://github.com/someone/their-omarchy-units
bo add their-thing
```

Units are named `marketplace/unit`, and you can drop the marketplace half when
only one offers that name.

**A marketplace is code that runs on your machine.** Units link scripts into
your `PATH` and QML into your shell process, unsandboxed. Read what you turn on.

## Writing a unit

One folder, and a README beside it saying how to use the thing. The only
required file is `unit.toml`.

```bash
bo new unit my-thing                   hypr/*.lua
bo new unit my-widget --kind plugin    plugin/manifest.json and Widget.qml
bo new unit my-setting --kind setting  apply.sh and revert.sh
```

That writes the folder below, filled in, and refuses to touch one that already
exists. It ends by printing the commands to run next.

```
units/undo-close/
  unit.toml        what this is, what it needs, which keys it claims
  README.md        how to use it, and what was hard about building it
  hypr/*.lua       linked into ~/.config/hypr/modules.d/
  bin/*            linked into ~/.local/bin/
  plugin/          linked into ~/.config/omarchy/plugins/<id>/   (kind = plugin)
  config/*         mirrored into ~/.config, path for path
  apply.sh         run on add                                    (kind = setting)
  revert.sh        run on remove                                 (kind = setting)
```

```toml
name     = "undo-close"
summary  = "Reopen the window you closed last"
version  = "0.1.0"
category = "Productivity"
tags     = ["hyprland", "windows"]
author   = "pehcastro"
kind     = "hypr"
needs    = ["hyprctl", "socat", "jq"]
keys     = ["SUPER+Z"]
```

It is a strict subset of TOML, `key = "value"` and `key = ["a", "b"]`, one per
line, so `bo` reads it with `sed` and no dependency. `needs` is what `bo doctor`
checks; `keys` is what `bo status` uses to catch two units fighting over one
binding.

`kind` only decides the extra step. Any unit may carry `hypr/`, `bin/` and
`config/` whatever its kind, because a bar widget that also wants a keybinding
is normal. `config/` is how one unit extends another program: a launcher
extension is just `config/omarchy/omacast/extensions/thing.json`.

Three things that will bite you:

- **Symlinks inside a plugin folder fail Omarchy's validator.** A symlinked
  plugin *directory* is fine, because the scanner uses `find -L`. That is why
  `bo` links the whole `plugin/` folder and never file by file.
- **Hyprland's `require_all` will not see your Lua.** It runs `find -type f`,
  which does not match a symlink. `bo` writes its own loader using `find -L` and
  `dofile`, so this is handled: just put `.lua` in `hypr/` and write it as you
  would any Omarchy Lua config.
- **Regenerate `registry.json` when you change a unit**, with `bo registry`. A
  stale registry means `bo update` reports no change and nobody gets your work.
  The `pre-commit` hook in `.githooks/` does it for you.

## Hosting a marketplace

Add a `marketplace.json` at your repo root, put units in `units/`, and commit a
generated `registry.json` beside them.

```json
{
  "name": "acme",
  "title": "Acme units",
  "description": "What this collection is for",
  "homepage": "https://github.com/acme/omarchy-units",
  "maintainer": "acme"
}
```

`name` is what users type: `bo add acme/thing`. The registry carries every field
from each `unit.toml` plus three things only git knows: the last `commit` that
touched the unit, its `updated` date, and a content `hash`. That hash is the
sha256 of every tracked file in the unit, so an unrelated commit leaves it
alone, and `bo update` can tell a real change from a reshuffle.

Then push. That is the whole distribution mechanism.

Before you publish, add your own repo as a local marketplace and try the round
trip: `bo add your/unit`, then `bo remove your/unit`, then check
`~/.config/hypr/modules.d`, `~/.local/bin` and `~/.config/omarchy/plugins` for
anything of yours still sitting there.

## Where things go

| Path | What |
|---|---|
| `~/.local/share/better-omarchy/marketplaces/<name>/` | each marketplace checkout |
| `~/.local/state/better-omarchy/linked` | which units are on |
| `~/.local/state/better-omarchy/installed.json` | the version and hash each was at |
| `~/.config/hypr/modules.d/` | symlinks to unit Lua files |
| `~/.config/omarchy/plugins/<id>/` | symlinks to unit plugin folders |
| `~/.local/bin/` | symlinks to unit scripts |

Your `~/.config/hypr/hyprland.lua` gets exactly one added line,
`require("hypr.modules")`. After that, adding a unit never edits a config file.

`monitors.lua` is machine-specific and is not tracked. `shell.json` is copied
rather than symlinked, because Omarchy replaces that file instead of editing it:
run `bo sync` after changing the bar to pull your version into the checkout.
