# better-omarchy

Omarchy customizations you can turn on and off one at a time, from any
marketplace.

```bash
curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
```

That installs the `bo` command, adds this repo as your first marketplace, and
lets you pick what you want. Nothing turns on without you choosing it.

## Units

**omarchycast** is the launcher. One box that answers with apps, arithmetic,
Omarchy commands, your own links, or the web, and shows each of those the way it
deserves rather than as one long list. `Ctrl+K` on any result shows what else it
can do.

**workspace-names** shows workspace names in the bar instead of numbers.
`Super+F2` opens a rename panel under the workspace you are renaming, with a
switch that decides between `coding` and `coding (2)`.

**undo-close** reopens the window you closed last, on `Super+Z`. Exactly one:
press it twice and the second press does nothing.

**cpu-meter** puts CPU load in the bar and opens btop on click. Omarchy ships no
CPU widget.

**zen-mode** lets a lone tiled window fill its workspace, with no gaps, border
or rounding. Open a second window and all three come back.

**familiar-keys** gives you the keys you already know: `Alt+F4` closes,
`Super+E` opens files, `Super+B` opens the browser, `Super+R` opens the app
menu.

**accents** types accented characters with AltGr, on a US keyboard. Plain typing
is unchanged: `'` and `"` do not wait for a second key.

**stay-awake** never locks or dims on idle. It sets Omarchy's own flag, so
`Super+Ctrl+I` still toggles it back.

**display-local** holds your monitor layout, gitignored, since that one file is
wrong on any other machine.

**keys-full**, **keys-balanced** and **keys-additive** decide what opens the
launcher. Exactly one at a time: `bo` refuses the second.

### Launcher extensions

Each is its own unit, so you take the ones you want.

**search-files** answers `file:report format:pdf`.
**search-images** answers `img:` with thumbnails, dimensions and size.
**search-windows** answers `win:` and jumps to an open window.
**search-music** answers `music:` with cover art, a progress bar and transport
control over MPRIS, so it works with any player, not just Spotify.
**clipboard-history** answers `ch:` from the history Omarchy already keeps.

## The launcher

Type anything. Apps, commands and your quicklinks come back ranked together.
Type `2+2*10` or `10 usd to eur` and the answer arrives large, with the
expression under it. Type something nothing matches and it offers to search the
web.

A `keyword:value` filter narrows to one source and tells it what you want:

```
file:report format:pdf     PDFs called report
img: in:~/work             thumbnails from somewhere else
win:chrome                 jump to that window
music:                     what is playing, with the cover
ch:token                   what you copied, with a preview
gh:omarchy plugin          your GitHub quicklink, with an argument
```

`=`, `>`, `?` and `/` are shorthands for calc, commands, web and file.

`Ctrl+K` opens everything else the selected result can do: copy the answer
rather than the expression, ask ChatGPT rather than Google, copy a file's path
rather than open it.

Settings live in `~/.config/omarchy/omarchycast.json` and take effect as you
save. That is where the default engine lives (Google), and your quicklinks:

```json
{
  "defaultEngine": "google",
  "quicklinks": [
    { "title": "GitHub", "keyword": "gh", "tags": ["dev"],
      "url": "https://github.com/search?q={}" },
    { "title": "Downloads", "keyword": "dl",
      "open": "nautilus --new-window ~/Downloads" }
  ]
}
```

### Writing an extension

An extension is a JSON file in `~/.config/omarchy/omarchycast/extensions/`
naming a keyword and a command. The command prints JSON rows, so it can be a
shell script, a Python file, or anything else that writes to stdout.

```json
{
  "id": "weather",
  "keyword": "wx",
  "title": "Weather",
  "search": "my-weather-lookup {query}",
  "when": "command -v my-weather-lookup",
  "view": "hero"
}
```

Each row is `{ id, title, subtitle, exec }`, plus optional `detail`,
`accessory`, `art`, `score`, `progress` and its own `actions`. `view` picks the
layout: `list`, `hero`, `cards`, `grid` or `split`.

`when` is checked once when the extension loads, not per keystroke, so an
extension for software you do not have costs nothing. Unscoped, an extension
stays quiet unless it sets `"always": true`.

Ship one as a unit by putting the JSON under
`config/omarchy/omarchycast/extensions/` and the script under `bin/`.

## bo

```
bo list                 every unit available, and whether it is on
bo search <term>        find a unit by name, summary, category or tag
bo info <unit>          everything known about one unit
bo status               what is on, plus keybinding conflicts

bo add [unit...]        turn units on (no argument opens a picker)
bo remove [unit...]     turn units off (no argument opens a picker)

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

One folder. The only required file is `unit.toml`.

```
units/undo-close/
  unit.toml        what this is, what it needs, which keys it claims
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
extension is just `config/omarchy/omarchycast/extensions/thing.json`.

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
