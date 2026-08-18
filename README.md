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
bo test [unit]          run each launcher extension and check what it prints
bo validate             run omarchy plugin validate on every plugin unit
bo registry             rebuild registry.json (for marketplace authors)
bo sync                 copy the live shell.json into this checkout
bo version              what this is and where it lives
```

## Someone else's units

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

## Further

- [docs/UNITS.md](docs/UNITS.md) is for writing one: the `unit.toml` fields,
  what each kind links where, and how to add a keyword to the launcher.
- [docs/MARKETPLACE.md](docs/MARKETPLACE.md) is for hosting a collection of
  your own: the registry, the hooks, and the release flow.
- [units/omacast/README.md](units/omacast/README.md) is the launcher itself:
  what you can type, every key, and the settings file.
