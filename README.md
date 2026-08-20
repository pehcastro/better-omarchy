# better-omarchy

A marketplace of Omarchy customizations, and the units that ship with it.

Omarchy's plugin system installs one plugin per git repo, and only QML. A
customization is usually more than that: a keybinding, a script, a config file,
something that must be installed first. This holds many of them in one repo,
installs what you pick, and takes it back out cleanly.

```bash
curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
```

That clones this repo, links `bo` into `~/.local/bin`, and leaves the clone as
your first marketplace. Nothing turns on until you choose it:

```bash
bo add          # a picker
bo list         # what there is, and what is on
```

## Add someone else's

A **marketplace** is any git repo with a `registry.json` at its root. Publishing
one is `git push`, and nobody approves it first.

```bash
bo market add https://github.com/someone/their-omarchy-units
bo list                       # theirs appear beside these
bo add their-thing
```

It also takes a plain Omarchy plugin repo, the kind `omarchy plugin add`
installs, and wraps it as a marketplace holding one unit.

With `omacast` on, type `bo:` in the launcher to walk the same marketplaces in a
window: the marketplaces and what you have, one marketplace as tiles, one unit's
page with its switch. `Enter` goes in, `Escape` comes back.

## Why another installer

Omarchy's plugin system is good at what it is for, and this builds on it rather
than replacing it, down to running `omarchy plugin validate` on every plugin
here. What it has no room for is more than one plugin per repo, and anything
that is not QML.

So three small customizations are three repos, three commands, and no way to
hand somebody your set. A **unit** is a folder that can carry a plugin, Hyprland
modules, scripts, config files and its own requirements, and `bo` records what it
linked so it can put everything back.

It buys no safety. `bo add` links scripts onto your `PATH` and can run a unit's
`apply.sh`, which `omarchy plugin add` never does. That reach is the trade.

[docs/WHY.md](docs/WHY.md) is the long version: what the manifest cannot hold,
where the one-plugin-one-repo limit comes from, how the registry model compares
to a central directory, and what removal can and cannot undo.

## The units in this marketplace

Five. `bo list` shows what is on, and every unit has a README beside it.

**[omacast](units/omacast/README.md)** is the launcher, and most of what this
repo is. Forty-one keywords in one box: apps, arithmetic, files, images,
windows, processes, git, GitHub, containers, music, radio, clipboard, notes,
reminders, themes, keybindings, timezones, a calendar, a system dashboard and
the web. `bo:` is one of them, so this marketplace is a screen in the launcher
as well as a command. Everything it answers ships inside it, including which
key opens it: `units/omacast/hypr/keys.lua` has three presets and one line to
switch.

**[better-workspaces](units/better-workspaces/README.md)** puts workspace names
in the bar instead of numbers. `Super+F2` renames the one you are on, `Super+=`
goes to the first free one, and a workspace nobody is using leaves the bar.

**[undo-close](units/undo-close/README.md)** reopens the window you closed last,
on `Super+Z`. Exactly one: press twice and the second press does nothing.

**[zen-mode](units/zen-mode/README.md)** lets a lone tiled window fill its
workspace, with no gaps, border or rounding. Open a second and all three return.

**[nkz-keys](units/nkz-keys/README.md)** is one person's setup: `Alt+F4`,
`Super+E`, `Super+B`, `Super+R`, `Super+grave`, and a `monitors.lua` that is
gitignored because that file is wrong on any other machine. Copy it, do not
add it.

## bo

```
bo list                 every unit available, and whether it is on
bo list --json          the same, for a program
bo search <term>        find a unit by name, summary, category or tag
bo info <unit>          everything known about one unit
bo status               what is on, plus keybinding conflicts
bo diff <unit>          what it changed, against the snapshot from install
bo snapshots            every snapshot here, including orphaned ones
bo restore <unit>       replay a snapshot, even if the unit is gone

bo add [unit...]        turn units on (no argument opens a picker)
bo remove [unit...]     turn units off (no argument opens a picker)
bo remove --purge ...   also delete a widget's bar position and settings

bo new unit <name>      start a unit here, filled in and ready to add
bo new extension <name> start a unit whose job is one launcher keyword

bo update               fetch every marketplace, show what changed, apply
bo outdated             linked units whose marketplace moved on
bo relink               apply those changes

bo market ...           add, link, remove and inspect marketplaces
bo doctor               check every linked unit's dependencies exist
bo uninstall            turn everything off and take bo off this machine
bo test [target...]     run launcher extensions and check what they print
bo test --fast          only the checks that run nothing
bo validate             run omarchy plugin validate on every plugin unit
bo registry [name]      rebuild a marketplace's registry.json (authors)
bo sync                 copy the live shell.json into this checkout
bo version              what this is and where it lives
```

Run `bo` with no arguments for the interactive version of all of this.

`bo test` takes a unit, a keyword, or `marketplace/unit`, and with no target it
checks everything. It runs four kinds of check, and `--only` picks them:
`manifest` reads `unit.toml` and each extension's own JSON, `answer` runs each
extension and reads the rows it prints, `actions` proves every action names a
program that exists, and `cases` runs the assertions in
`<extension>.cases.json`. `--fast` is `--only manifest`.

`bo uninstall` is the way out. It turns every unit off one at a time, so each
one puts back whatever it displaced, then deletes `bo`'s state directory, its
clones and its `~/.local/bin/bo` link. It names anything it moved aside and
could not put back. It never deletes a tree you linked, and it never deletes
this checkout.

Nothing that runs code or pulls a change in happens without being asked first.
`--yes` answers yes to every question, for scripts.

## Further

- [docs/WHY.md](docs/WHY.md) is why this exists and what it trades away.
- [docs/UNITS.md](docs/UNITS.md) is for writing one: the `unit.toml` fields,
  what each kind links where, and how to add a keyword to the launcher.
- [docs/CONTRACT.md](docs/CONTRACT.md) is what a unit promises about what it
  touches, and what removal does with each kind of change.
- [docs/MARKETPLACE.md](docs/MARKETPLACE.md) is for hosting a collection of
  your own: the registry, the hooks, and the release flow.
- [units/omacast/README.md](units/omacast/README.md) is the launcher itself:
  what you can type, every key, and the settings file.
