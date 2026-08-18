# better-omarchy

Omarchy customizations you can turn on and off one at a time, from any
marketplace.

```bash
curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
```

That installs the `bo` command, adds this repo as your first marketplace, and
lets you pick what you want. Nothing turns on without you choosing it.

## The idea

A **unit** is one customization: a bar widget, a keybinding, a Hyprland rule, a
system setting. It is a folder saying what it touches, what it needs, and which
keys it claims. Turning one off leaves nothing behind.

A **marketplace** is a git repo holding units plus a `registry.json`. This repo
is one. Point `bo` at anyone else's and their units appear in your list next to
these:

```bash
bo market add https://github.com/someone/their-omarchy-units
bo list
bo add their-thing
```

Units are named `marketplace/unit`, and you can drop the marketplace half when
only one offers that name.

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
which units changed, which of those you actually have on, and whether the author
bumped the version:

```
better-omarchy
  changed  on workspaces           0.1.0 -> 0.2.0
  new         clipboard            0.1.0  Clipboard history in the bar
  changed     cpu                  0.1.0 (content changed, version did not)
  updated d5d89fe4451b -> 8c0f1a92be40
```

## Units here

| Unit | What it does | Keys |
|---|---|---|
| `workspaces` | Workspace **names** in the bar instead of numbers, with a rename panel that opens under the workspace you are renaming. A "keep number" switch decides between `coding` and `coding (2)`. | `SUPER+F2` |
| `cpu` | CPU load in the bar. Click opens btop. Omarchy ships no CPU widget. | |
| `reopen` | Reopens the window you closed last. Exactly one: press twice and the second press does nothing. | `SUPER+Z` |
| `windows-keys` | `ALT+F4` closes, `SUPER+E` opens files, `SUPER+B` opens the browser, `SUPER+R` opens the app menu. | `ALT+F4` `SUPER+E` `SUPER+B` `SUPER+R` |
| `my-apps` | Typora on `SUPER+SHIFT+W`, replacing Omawrite. | `SUPER+SHIFT+W` |
| `keyboard-intl` | US keyboard with AltGr accents. Plain typing is unchanged: `'` and `"` do not wait for a second key. | |
| `single-window-zen` | A workspace with one tiled window drops its gaps, border and rounding, so one app reads as full screen. Open a second window and all three come back. | |
| `no-idle-lock` | Never lock or start the screensaver on idle. Uses Omarchy's stay-awake flag, so `SUPER+CTRL+I` still toggles it back. | |

## Writing units, hosting a marketplace

See [docs/AUTHORING.md](docs/AUTHORING.md). Short version: a unit is a folder
with a `unit.toml`, and a marketplace is a repo with a `marketplace.json` and a
generated `registry.json`.

## Where things go

| Path | What |
|---|---|
| `~/.local/share/better-omarchy/marketplaces/<name>/` | each marketplace checkout |
| `~/.local/state/better-omarchy/linked` | which units are on |
| `~/.local/state/better-omarchy/installed.json` | the version and content hash each was at |
| `~/.config/hypr/modules.d/` | symlinks to unit Lua files |
| `~/.config/omarchy/plugins/<id>/` | symlinks to unit plugin folders |
| `~/.local/bin/` | symlinks to unit scripts |

Your `~/.config/hypr/hyprland.lua` gets exactly one added line,
`require("hypr.modules")`. After that, adding a unit never edits a config file.

## Not tracked

`monitors.lua` is machine-specific. `shell.json` is copied rather than
symlinked, because Omarchy replaces that file instead of editing it: run
`bo sync` after changing the bar to pull your version into the checkout.

## A warning worth repeating

A marketplace is code that runs on your machine. Units link scripts into your
`PATH` and QML into your shell process, unsandboxed. Read what you turn on.
